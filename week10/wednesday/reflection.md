# Week 10 Wednesday Reflection

## Lab Analysis Question

**Tendo asks: "In the current chain, if `kk-processor` crashes on `ORD-003` after `kk-receipts` has already written the processed file, what happens? Does `kk-receipts` retry? Does `kk-processor` retry? Does `kk-notifier` ever fire for `ORD-003`? What would need to change in the architecture to guarantee that a processor crash does not silently drop a notification?" Answer precisely, naming the missing component.**

If `kk-processor` crashes after `kk-receipts` has successfully written `processed-ORD-003.json`, the `kk-receipts` stage has already completed successfully and does not know that the downstream processor failed. It therefore does not retry the receipt-generation step.

In the simple bucket-chaining architecture used in this lab, there is no durable intermediary between the S3 event and the processor that explicitly provides the retry and failure-handling guarantees we would want in a production workflow. If the processor invocation ultimately fails and the event is not successfully handled, `kk-notifier` will not fire because `kk-processor` never writes the corresponding `notify-ORD-003.json` object to the notifications bucket.

The missing production component is a **message queue with retry and dead-letter queue support**, such as SQS with a DLQ. Instead of relying only on bucket-to-function chaining, the S3 event could be delivered through a durable queue. The processor would consume the queued message, failed processing could be retried, and events that repeatedly fail could be moved to a dead-letter queue for investigation rather than disappearing silently.

This is why the Wednesday reading notes that bucket chaining is useful for demonstrating event-driven architecture locally, while message queues or workflow orchestrators are better suited to production workflows that require guaranteed delivery, retries, and failure recovery.

---

## Question 1

**The `resources` block in `serverless.yml` declares the three S3 buckets. Before adding this block, the buckets had to be created manually with the AWS CLI. Explain what specific operational risk the manual creation approach creates in a team of five engineers, and how declaring resources in `serverless.yml` eliminates that risk. Reference the Week 4 Terraform parallel explicitly in your answer.**

Manual bucket creation creates a **configuration drift and reproducibility risk**. In a team of five engineers, each person has to know that the buckets must exist, remember the correct names, create them in the correct order, and use the correct stage. One engineer might create `kk-receipts-processed-dev`, another might use a slightly different name, and another might forget to create a required bucket entirely. The application code could therefore be identical across all five machines while the supporting infrastructure is different.

We experienced part of this problem on Tuesday when we manually used the AWS CLI against the local S3 server. A fresh checkout of the repository alone was not enough to describe the complete working system because bucket creation existed as knowledge outside the repository.

Declaring the buckets in the `resources` block moves that infrastructure definition into source control alongside the functions and triggers. A fresh environment can therefore derive the required resources from the same `serverless.yml` rather than depending on engineers reproducing a sequence of manual commands.

This directly parallels **Week 4 Terraform**. In Terraform, we declared resources in `main.tf` and allowed `terraform apply` to create the required infrastructure consistently instead of asking every engineer to create VMs, networking, and related resources manually. Likewise, Wednesday's `resources` block describes what S3 resources should exist. The important principle in both cases is that the infrastructure becomes **declarative, version-controlled, and reproducible**.

---

## Question 2

**The `custom` block defines bucket names as `kk-payments-receipts-${self:provider.stage}`. If Amina runs `serverless offline start` (stage: dev) and a colleague runs `serverless offline start --stage staging`, what are the bucket names in each environment, and why does this pattern prevent the two environments from interfering with each other's data?**

The stage value is incorporated directly into each bucket name.

With the default `dev` stage, the three bucket names resolve to:

```text
kk-payments-receipts-dev
kk-receipts-processed-dev
kk-notifications-queue-dev
```

If a colleague starts the stack with:

```bash
serverless offline start --stage staging
```

the same configuration resolves to:

```text
kk-payments-receipts-staging
kk-receipts-processed-staging
kk-notifications-queue-staging
```

The important part is that both environments use the same `serverless.yml`, but `${self:provider.stage}` gives their resources different physical names. A receipt generated in the development environment is therefore written to a `-dev` bucket, while staging writes to its corresponding `-staging` bucket.

This prevents the two environments from processing each other's objects. Without the suffix, both stacks could point at the same bucket, meaning a development upload could accidentally trigger a staging function or staging test data could be overwritten or consumed by development code. Stage-specific resource names provide isolation while still allowing one configuration file to describe all environments.

---

## Question 3

**Each function in the chain uses the `orderId` as a correlation ID in its log output. A production incident occurs at 14:32 and a customer reports their receipt was never delivered. Describe the exact sequence of log queries an engineer would run to determine whether the failure occurred in `kk-receipts`, `kk-processor`, or `kk-notifier`, and what the presence or absence of each log line would indicate.**

The engineer would first obtain the customer's `orderId`, for example `ORD-003`, and use it as the correlation ID when searching logs around 14:32.

The first query would look for the `kk-receipts` generation event:

```bash
grep 'ORD-003' logs | grep '"service":"kk-receipts"'
```

The expected entry would contain:

```text
"event":"receipt.generated"
```

If this entry is missing, the chain failed at or before the first function. The HTTP request may not have reached `kk-receipts`, validation may have failed, or the handler may have failed before successfully generating and queuing the receipt.

If `receipt.generated` exists, the engineer would next search for the processor event:

```bash
grep 'ORD-003' logs | grep '"service":"kk-processor"'
```

The expected entry is:

```text
"event":"receipt.processed"
```

If the receipt-generation log exists but the processor log does not, the receipt reached the first stage but the chain stopped between the processed-bucket write and completion of `kk-processor`. The engineer would then investigate the S3 trigger and processor invocation.

If both of those entries exist, the engineer would search for the notifier:

```bash
grep 'ORD-003' logs | grep '"service":"kk-notifier"'
```

The expected entry contains:

```text
"event":"notification.dispatched"
```

If `receipt.generated` and `receipt.processed` exist but `notification.dispatched` does not, the problem occurred after processor completion and before or during notifier execution.

If all three entries exist, then the internal serverless chain completed successfully. The investigation would need to move beyond these three stages—for example, to the actual external SMS or email provider that a production version of `kk-notifier` would call.

Because the same `orderId` is included in every stage's filename and structured log, the engineer can reconstruct the complete path of one receipt even when logs from many different orders are interleaved.

---

## Question 4

**The `process` export name in `handlers/processor.js` was renamed `process_`. Write a short test that demonstrates the shadowing bug that would occur if the handler used `process` as both the export name and attempted to read `process.env.NODE_ENV` inside the same function, and explain why the rename fixes it.**

A small example demonstrating the problem is:

```js
const process = async () => {
  console.log(process.env.NODE_ENV);
};

process();
```

In Node.js, `process` normally refers to the global Node process object, which provides properties such as:

```js
process.env.NODE_ENV;
```

However, in this example the local function is also named `process`. Inside the function, that local identifier shadows the global Node.js `process` object. Therefore, `process.env` refers to a property on the function rather than the Node runtime's environment object. Since that function does not have an `env` property, attempting to access `process.env.NODE_ENV` fails instead of reading the environment variable.

A simple demonstration would therefore produce an error similar to trying to access `NODE_ENV` from `undefined`.

Using a different internal function name avoids the collision:

```js
const process_ = async () => {
  console.log(process.env.NODE_ENV);
};

module.exports = { process: process_ };
```

Here, `process_` is the function's local name, so `process` inside the function continues to refer to Node.js's global process object. At the same time, `module.exports` can still expose the handler under the name `process`, allowing the Serverless configuration to reference:

```yaml
handler: handlers/processor.process
```

This keeps the desired external handler name while preventing the local function from shadowing the global `process` object.
