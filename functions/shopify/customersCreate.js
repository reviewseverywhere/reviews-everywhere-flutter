'use strict';

// functions/shopify/customersCreate.js

const { verifyShopifyWebhook } = require('./verifyShopify');
const {
  upsertAccountFromCustomer,
  acquireWebhookLock,
  markWebhookProcessed,
  markWebhookFailed,
} = require('./common');

async function customersCreateHandler(req, res) {
  let lock = null;

  try {
    if (req.method === 'GET') {
      res.status(200).send('customers/create webhook live');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    if (!verifyShopifyWebhook(req)) {
      console.error('Invalid HMAC on customers/create');
      res.status(401).send('Unauthorized');
      return;
    }

    const customer = req.body || {};
    const customerId = customer?.id != null ? String(customer.id) : null;

    lock = await acquireWebhookLock(req, {
      topic: 'customers/create',
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

    console.log('▶️ customers/create', { id: customerId, email: customer?.email || null });

    await upsertAccountFromCustomer(customer);

    await markWebhookProcessed(lock.eventRef);
    res.status(200).send('OK');
  } catch (err) {
    console.error('Error in customersCreateHandler:', err);
    if (lock?.eventRef) {
      try {
        await markWebhookFailed(lock.eventRef, err);
      } catch (_) {}
    }
    res.status(500).send('Internal error');
  }
}

module.exports = { customersCreateHandler };
