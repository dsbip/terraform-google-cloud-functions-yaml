// Accepts an order as JSON and echoes it back with an ID. The API key comes
// from Secret Manager through the ORDERS_API_KEY environment variable.
const functions = require('@google-cloud/functions-framework');
const crypto = require('crypto');

functions.http('createOrder', (req, res) => {
  if (req.get('x-api-key') !== process.env.ORDERS_API_KEY) {
    res.status(401).send('unauthorized');
    return;
  }
  res.status(201).json({ id: crypto.randomUUID(), ...req.body });
});
