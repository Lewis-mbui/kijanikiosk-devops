# Week 10 Tuesday Reflection

## Lab Analysis Question

**Osei reviews the lab and asks: "`kk-payments` currently writes the receipt file to the local bucket manually during development. In production, what code change would `kk-payments` need to make to trigger `kk-receipts` automatically, and what does `kk-payments` need to know about `kk-receipts` to do it?" Answer this precisely, naming what `kk-payments` does and does not need to know.**

In production, `kk-payments` would need code that writes a receipt-request object to the configured object-storage bucket after a successful payment. The object would follow the agreed naming and data contract, for example `receipt-ORD-001.json` containing the `orderId`, amount, and currency. Creating that object generates the `ObjectCreated` event, which then causes the platform to invoke `processReceiptUpload` automatically.

`kk-payments` therefore needs to know the **bucket or event destination and the agreed object schema/naming convention**. It does not need to know the `kk-receipts` function name, URL, port, runtime, deployment details, or how the receipt consumer is implemented.

## This is the main decoupling benefit demonstrated in the lab. During Phase 2, uploading `receipt-ORD-101.json`, `receipt-ORD-102.json`, and `receipt-ORD-103.json` caused three separate structured log entries to appear without directly invoking `processReceiptUpload`. The producer interacted only with the bucket, while the event system connected the upload to the consumer.

## Question 1

**Architecture A (Page 2) has `kk-payments` making a synchronous HTTP call to `kk-receipts`. Architecture B has `kk-payments` writing a file to a bucket. Identify all the things `kk-payments` needs to know in Architecture A that it does not need to know in Architecture B, and explain how each of those eliminated dependencies reduces operational risk.**

In Architecture A, `kk-payments` must know where and how to contact `kk-receipts`. This includes its **URL or hostname, port, HTTP endpoint, request format, response format, availability, and expected response behaviour**. Because `kk-payments` waits for the HTTP response, it is also affected by `kk-receipts` latency, cold starts, errors, and timeouts.

These dependencies introduce several operational risks. Knowing the URL and port creates infrastructure coupling because a networking or deployment change to `kk-receipts` can require a corresponding configuration change in `kk-payments`. Depending on the HTTP API contract creates deployment coupling because changing that API may require coordinated releases of both services. Waiting for a response creates latency coupling because any slow execution or cold start is added directly to the customer's payment response. Finally, synchronous communication creates failure coupling because a timeout or `500` response from `kk-receipts` forces `kk-payments` to decide how the payment itself should behave.

Architecture B removes those direct dependencies. `kk-payments` only needs to know the storage destination and the agreed event contract, such as the `receipt-{orderId}.json` naming convention and expected JSON contents. It does not know which function consumes the event or even whether a serverless function is the consumer. This reduces operational risk because `kk-receipts` can fail, restart, cold-start, or be redeployed without causing the successful payment request itself to fail.

---

## Question 2

**Osei's first question is about event redelivery. S3-triggered Lambda functions in production can receive the same event more than once if the first invocation failed. Your current handler would then process the same receipt upload twice. Describe what idempotency means in this context and what specific change to the handler logic (referencing Monday's `receiptId` TODO) would make it safe to process the same event twice.**

Idempotency means that processing the **same receipt event more than once produces the same final result as processing it once**. If the storage event for `ORD-001` is delivered twice, the system should still have one logical receipt for `ORD-001`, not two different receipts.

Monday's handler currently generates a receipt ID using `crypto.randomUUID()`. That is appropriate for generating unique IDs, but using a new random UUID on every repeated processing attempt would make duplicate delivery dangerous: the first invocation could create one receipt ID and the second invocation could create a different one for the same order.

To make the operation idempotent, the receipt identity should instead be **deterministically tied to `orderId`**, or the handler should store and look up the existing receipt using `orderId` as a unique key before creating another one. For example, processing `ORD-001` twice should resolve to the same receipt record or receipt identifier both times.

The Tuesday reading specifically identifies duplicate event delivery as a challenge and states that `kk-receipts` must be idempotent so that generating the same receipt twice for the same `orderId` produces the same result rather than two receipts.

---

## Question 3

**The `processReceiptUpload` function iterates over `event.Records` rather than accessing `event.Records[0]` directly. Explain when `event.Records` would contain more than one record for an S3 trigger and what would go wrong if the handler only processed the first record in that scenario.**

S3 events use a `Records` array because one invocation can contain more than one event record. The reading notes that single-upload scenarios commonly contain one record, while **batch upload scenarios or SQS-backed S3 notifications can contain multiple records**.

If the handler accessed only `event.Records[0]`, it would process the first uploaded object and silently ignore every remaining record in the same invocation. For example, if an invocation contained receipt events for `ORD-001`, `ORD-002`, and `ORD-003`, a handler using only index `0` would process `ORD-001` and fail to process the other two receipts.

Our implementation avoids this by using:

```js
for (const record of event.Records) {
  // process each storage event independently
}
```

This also matches the Tuesday exercise where the handler was tested with multiple records to verify that a distinct log entry could be produced for each one. Iterating through the entire array prevents legitimate receipt requests from being dropped when multiple records are delivered together.

---

## Question 4

**The schedule trigger in Page 3 uses `cron(1 0 1 * ? *)`. Translate this into plain language, identify the KijaniKiosk use case it was designed for, and explain what additional design consideration is needed if the function it triggers takes longer than the Serverless Framework's default timeout to complete.**

The expression:

```text
cron(1 0 1 * ? *)
```

uses AWS EventBridge cron syntax and means **run at 00:01 on the first day of every month**.

The KijaniKiosk use case given in the reading is generating the **end-of-month payment summary report automatically**. Instead of an engineer manually starting the report, the schedule event invokes the function at 00:01 on the first of each month.

A serverless function is designed to be short-lived and is subject to an execution timeout. Therefore, if the monthly report could take longer than the permitted function execution time, the workload should not simply be allowed to continue indefinitely. The design would need to account for the timeout by either configuring an appropriate supported timeout or restructuring the work into smaller units that can complete within the execution limit, potentially processing the report asynchronously in stages.

The Tuesday reading explains that functions have maximum execution durations but does **not specify the Serverless Framework's exact default timeout value**, so the important design point from the supplied material is to ensure the scheduled workload can complete within the configured/provider execution limit rather than assuming a long-running task can execute indefinitely.
