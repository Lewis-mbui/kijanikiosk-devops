const notify = async (event) => {
  for (const record of event.Records) {
    const key = decodeURIComponent(
      record.s3.object.key.replace(/\+/g, ' ')
    );

    const orderId = key
      .replace(/^notify-/, '')
      .replace(/\.json$/, '');

    console.log(JSON.stringify({
      service: 'kk-notifier',
      event: 'notification.dispatched',
      orderId,
      channel: process.env.NOTIFICATION_CHANNEL,
      dispatchedAt: new Date().toISOString()
    }));
  }
};

module.exports = { notify };