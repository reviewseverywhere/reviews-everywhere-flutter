'use strict';

// functions/shopify/customersUpdate.js

const { verifyShopifyWebhook } = require('./verifyShopify');
const {
  upsertAccountFromCustomer,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
} = require('./common');

async function customersUpdateHandler(req, res) {
  let lock = null;

  try {
    if (req.method === 'GET') {
      res.status(200).send('customers/update webhook live');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    if (!verifyShopifyWebhook(req)) {
      console.error('Invalid HMAC on customers/update');
      res.status(401).send('Unauthorized');
      return;
    }

    const customer = req.body || {};
    const customerId = customer?.id != null ? String(customer.id) : null;

    lock = await acquireWebhookLock(req, {
      topic: 'customers/update',
      customerId,
    });

    if (!lock.shouldProcess) {
      res.status(200).send('OK');
      return;
    }

    if (!customerId) {
      await markWebhookProcessed(lock.eventRef);
      res.status(200).send('OK');
      return;
    }

    console.log('▶️ customers/update', { id: customerId, email: customer?.email || null });

    await upsertAccountFromCustomer(customer);

    await markWebhookProcessed(lock.eventRef);
    res.status(200).send('OK');
  } catch (err) {
    console.error('Error in customersUpdateHandler:', err);
    if (lock?.eventRef) {
      try {
        await markWebhookFailed(lock.eventRef, err);
      } catch (_) {}
    }
    res.status(500).send('Internal error');
  }
}

module.exports = { customersUpdateHandler };
