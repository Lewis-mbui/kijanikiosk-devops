const generateReceipt = async (event) => {
  const body = JSON.parse(event.body || '{}');

  if (!body.orderId || body.amount === undefined) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'orderId and amount are required'
      })
    };
  }

  const receipt = {
    receiptId: crypto.randomUUID(),
    orderId: body.orderId,
    amount: body.amount,
    currency: body.currency || process.env.DEFAULT_CURRENCY,
    timestamp: new Date().toISOString(),
    status: 'generated'
  };

  console.log(`[kk-receipts] Receipt generated for order ${receipt.orderId}`);

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(receipt)
  };
};

module.exports = { generateReceipt };