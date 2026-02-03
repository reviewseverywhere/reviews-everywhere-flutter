'use strict';

// functions/tap/tapRedirect.js
const admin = require('firebase-admin');
const { verifyTapToken } = require('./token');
const { incrementDailyRollup } = require('./rollups');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function isValidHttpsUrl(u) {
  try {
    const x = new URL(String(u));
    return x.protocol === 'https:' && x.hostname.length > 0;
  } catch (_) {
    return false;
  }
}

function computeFreezeAt(firstTapAtDate) {
  // 21 days from Day 0
  return new Date(firstTapAtDate.getTime() + 21 * 24 * 60 * 60 * 1000);
}

function offlineAnalyticsIsLive(planTier) {
  // Client logic:
  // - freemium: live until day 21
  // - frozen: stop updating
  // - standard: live again (unfrozen)
  // - premium_gbp: live
  return planTier === 'freemium' || planTier === 'standard' || planTier === 'premium_gbp';
}

async function tapRedirectHandler(req, res) {
  res.set('Cache-Control', 'no-store');

  try {
    const token = req.query.t;
    if (!token) {
      res.status(400).send('Missing token');
      return;
    }

    // 1) Verify token → get accountId + wristbandId
    const { accountId, wristbandId } = verifyTapToken(token);

    const accountRef = db.collection('accounts').doc(accountId);
    const wristbandRef = accountRef.collection('wristbands').doc(wristbandId);

    // 2) Load wristband
    const wristSnap = await wristbandRef.get();
    if (!wristSnap.exists) {
      res.status(404).send('Wristband not found');
      return;
    }

    const wrist = wristSnap.data() || {};
    const teamId = wrist.teamId ? String(wrist.teamId) : null;
    const operatorName = wrist.operatorName ? String(wrist.operatorName) : null;

    if (!teamId) {
      res.status(409).send('Wristband is not assigned to a team');
      return;
    }

    // 3) Load team url
    const teamRef = accountRef.collection('teams').doc(teamId);
    const teamSnap = await teamRef.get();
    if (!teamSnap.exists) {
      res.status(404).send('Team not found');
      return;
    }

    const team = teamSnap.data() || {};
    const destinationUrl = team.url;

    if (!isValidHttpsUrl(destinationUrl)) {
      res.status(409).send('Team URL is not configured');
      return;
    }

    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);

    // 4) Transaction for: Day-0 fields + planTier transitions + tap log + rollups gating
    await db.runTransaction(async (tx) => {
      const accountSnap = await tx.get(accountRef);
      const account = accountSnap.exists ? (accountSnap.data() || {}) : {};

      // planTier default
      let planTier = account.planTier ? String(account.planTier) : 'freemium';

      const firstTapAtTs = account?.freemium?.firstTapAt || null;
      let firstTapAtDate = firstTapAtTs ? firstTapAtTs.toDate() : null;

      // Set Day 0 on first real tap
      if (!firstTapAtDate) {
        firstTapAtDate = now;
        const freezeAtDate = computeFreezeAt(firstTapAtDate);

        tx.set(
          accountRef,
          {
            planTier: 'freemium',
            freemium: {
              firstTapAt: nowTs,
              freezeAt: admin.firestore.Timestamp.fromDate(freezeAtDate),
            },
            analytics: {
              lastUpdatedAt: nowTs,
            },
            updatedAt: nowTs,
          },
          { merge: true }
        );

        planTier = 'freemium';
      } else {
        // Existing Day 0 → check freeze
        const freezeAtTs = account?.freemium?.freezeAt || null;
        const freezeAtDate = freezeAtTs ? freezeAtTs.toDate() : computeFreezeAt(firstTapAtDate);

        // Auto-transition to Frozen only if still freemium and time passed
        if (planTier === 'freemium' && now >= freezeAtDate) {
          planTier = 'frozen';
          tx.set(
            accountRef,
            {
              planTier: 'frozen',
              analytics: { lastUpdatedAt: account?.analytics?.lastUpdatedAt || nowTs },
              updatedAt: nowTs,
            },
            { merge: true }
          );
        }
      }

      // 5) Write tap log (always, even if frozen; marked counted true/false)
      const tapRef = accountRef.collection('taps').doc();
      tx.set(tapRef, {
        ts: nowTs,
        wristbandId,
        teamId,
        operatorName: operatorName || null,
        tokenVersion: 'v1',
        planTierAtTap: planTier,
        countedInAnalytics: offlineAnalyticsIsLive(planTier),
      });

      // 6) Update rollups only when offline analytics is live (NOT frozen)
      if (offlineAnalyticsIsLive(planTier)) {
        // We cannot call non-transactional helper here; build the same increments in transaction
        const dateId = (() => {
          const y = now.getUTCFullYear();
          const m = String(now.getUTCMonth() + 1).padStart(2, '0');
          const d = String(now.getUTCDate()).padStart(2, '0');
          return `${y}-${m}-${d}`;
        })();

        const dailyRef = accountRef
          .collection('rollups')
          .doc('daily')
          .collection('days')
          .doc(dateId);

        const inc = admin.firestore.FieldValue.increment(1);

        const update = {
          totalTaps: inc,
          updatedAt: nowTs,
          lastTapAt: nowTs,
        };
        update[`byTeam.${teamId}`] = inc;
        update[`byWristband.${wristbandId}`] = inc;
        if (operatorName) update[`byOperator.${operatorName}`] = inc;

        tx.set(dailyRef, update, { merge: true });

        // Update account lastUpdatedAt for UI “Frozen – last updated …”
        tx.set(
          accountRef,
          { analytics: { lastUpdatedAt: nowTs }, updatedAt: nowTs },
          { merge: true }
        );
      }
    });

    // 7) Redirect to team.url
    res.redirect(302, destinationUrl);
  } catch (err) {
    console.error('tapRedirect error:', err);
    res.status(400).send('Invalid request');
  }
}

module.exports = { tapRedirectHandler };
