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

const process_ = async (event) => {
  for (const record of event.Records) {
    const key = decodeURIComponent(
      record.s3.object.key.replace(/\+/g, ' ')
    );

    const orderId = key
      .replace(/^processed-/, '')
      .replace(/\.json$/, '');

    const payload = {
      orderId,
      processingTimestamp: new Date().toISOString(),
      sourceKey: key
    };

    await s3.send(new PutObjectCommand({
      Bucket: process.env.NOTIFIER_BUCKET,
      Key: `notify-${orderId}.json`,
      Body: JSON.stringify(payload),
      ContentType: 'application/json'
    }));

    console.log(JSON.stringify({
      service: 'kk-processor',
      event: 'receipt.processed',
      orderId
    }));
  }
};

module.exports = { process: process_ };