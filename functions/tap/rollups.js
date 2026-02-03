'use strict';

// functions/tap/rollups.js
const admin = require('firebase-admin');

function yyyyMmDd(d) {
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Updates:
 * accounts/{accountId}/rollups/daily/{YYYY-MM-DD}
 */
async function incrementDailyRollup({
  db,
  accountId,
  teamId,
  wristbandId,
  operatorName,
  now = new Date(),
}) {
  const dateId = yyyyMmDd(now);
  const ref = db
    .collection('accounts')
    .doc(String(accountId))
    .collection('rollups')
    .doc('daily')
    .collection('days')
    .doc(dateId);

  const inc = admin.firestore.FieldValue.increment(1);
  const ts = admin.firestore.Timestamp.fromDate(now);

  const update = {
    totalTaps: inc,
    updatedAt: ts,
    lastTapAt: ts,
  };

  if (teamId) update[`byTeam.${String(teamId)}`] = inc;
  if (wristbandId) update[`byWristband.${String(wristbandId)}`] = inc;
  if (operatorName) update[`byOperator.${String(operatorName)}`] = inc;

  await ref.set(update, { merge: true });
}

module.exports = { incrementDailyRollup };
