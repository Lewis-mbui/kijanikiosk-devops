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

const processReceiptUpload = async (event) => {
  for (const record of event.Records) {
    const objectKey = decodeURIComponent(
      record.s3.object.key.replace(/\+/g, ' ')
    );

    let orderId = objectKey
      .replace(/^receipt-/, '')
      .replace(/\.json$/, '');

    let warning;

    if (!orderId || orderId === objectKey) {
      orderId = 'UNKNOWN';
      warning = 'malformed key: could not extract orderId';
    }

    const logEntry = {
      service: 'kk-receipts',
      event: 'receipt.upload.received',
      orderId,
      bucketName: record.s3.bucket.name,
      objectKey,
      fileSizeBytes: record.s3.object.size,
      uploadedAt: record.eventTime,
      processedAt: new Date().toISOString(),
      currency: process.env.DEFAULT_CURRENCY,
      ...(warning && { warning })
    };

    console.log(JSON.stringify(logEntry));
  }
};

module.exports = { generateReceipt, processReceiptUpload };