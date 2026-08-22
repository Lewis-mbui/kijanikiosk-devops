const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const s3 = new S3Client({
  endpoint: process.env.S3_ENDPOINT || 'http://localhost:4569',
  region: 'af-south-1',
  forcePathStyle: true,
  credentials: {
    accessKeyId: 'S3RVER',
    secretAccessKey: 'S3RVER'
  }                           
});

const generate = async (event) => {
  const body = typeof event.body === 'string'
    ? JSON.parse(event.body)
    : (event.body || {});

  const orderId = body.orderId;

  if (!orderId) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'orderId is required'
      })
    };
  }

  const receipt = {
    receiptId: `RCP-${Date.now()}`,
    orderId,
    amount: body.amount,
    currency: body.currency || process.env.DEFAULT_CURRENCY,
    timestamp: new Date().toISOString(),
    status: 'generated'
  };

  await s3.send(new PutObjectCommand({
    Bucket: process.env.OUTPUT_BUCKET,
    Key: `processed-${orderId}.json`,
    Body: JSON.stringify(receipt),
    ContentType: 'application/json'
  }));

  console.log(JSON.stringify({
    service: 'kk-receipts',
    event: 'receipt.generated',
    orderId,
    receiptId: receipt.receiptId
  }));

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      receiptId: receipt.receiptId,
      orderId,
      status: 'queued'
    })
  };
};

module.exports = { generate };