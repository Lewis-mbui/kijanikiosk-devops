# Week 10 Monday Reflection

## Question 1

**The kk-payments service currently runs 3 replicas around the clock. kk-receipts runs zero processes when idle. Explain what this means for resource consumption at 3am when no payments are being processed, and identify the specific trade-off that kk-payments cannot make that kk-receipts can.**

At 3am when no payments are being processed, the three `kk-payments` Pods are still running. Kubernetes continues allocating their requested CPU and memory and checking their health even though there is no useful work for them to perform. This is appropriate for `kk-payments` because it is a customer-facing service that must remain available and provide predictable response times whenever a payment request arrives.

`kk-receipts` uses a different execution model. As a serverless function, it can scale to zero when there are no receipt events, meaning there is no continuously running application process consuming resources while idle. When an event arrives, the platform starts or reuses a runtime instance, executes the function, and can eventually release that instance again.

The trade-off is **resource consumption versus startup latency**. `kk-payments` cannot comfortably scale to zero because a customer could be waiting for the service to start before their payment request is processed. `kk-receipts` can accept a possible cold start because receipt generation is a short-lived background task that does not require a permanently running process.

## Question 2

**Amina's handler parses `event.body` using `JSON.parse(event.body || '{}')`. Explain why the `|| '{}'` fallback is necessary, what the handler should do if `orderId` is missing from the parsed body, and write the validation logic that should replace the first TODO comment.**

The `|| '{}'` fallback ensures that if `event.body` is missing or empty, `JSON.parse()` receives a valid empty JSON object instead. This allows the handler to continue to validation rather than immediately failing while parsing an empty body.

If `orderId` or `amount` is missing, the function should not generate an incomplete receipt. It should return a `400` response indicating that the required input was not provided. We implemented the validation as:

```js
if (!body.orderId || body.amount === undefined) {
  return {
    statusCode: 400,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      error: "orderId and amount are required",
    }),
  };
}
```

We verified this by invoking the function with only `"amount":2500`. The function returned `statusCode: 400` with the error `"orderId and amount are required"`.

We also tested `"body":"not-json"` and observed a `SyntaxError` from `JSON.parse()`. This demonstrated that `event.body || '{}'` only protects against a missing or empty body. A malformed but non-empty body is still passed to `JSON.parse()` and causes an exception. Handling malformed JSON gracefully would therefore require additional error handling such as a `try/catch`.

## Question 3

**The `serverless.yml` defines `DEFAULT_CURRENCY: KES` at the provider level and the handler reads it via `process.env.DEFAULT_CURRENCY`. A new engineer asks: "Can we just hardcode KES in the handler and skip the environment variable?" Give two specific reasons why the environment variable approach is better, referencing what you learned in Week 9 about configuration separation.**

The first reason is **separation of configuration from application logic**. `KES` is a configuration value rather than part of the receipt-generation algorithm. Keeping it in `serverless.yml` means the default currency can be changed for another environment without modifying the handler itself. This follows the same principle we used in Week 9 when application configuration was moved into Kubernetes ConfigMaps rather than being hardcoded into the application.

The second reason is that this approach provides a pattern that also works for configuration that must not be committed to source control. Serverless can reference external values using syntax such as `${env:DB_PASSWORD}`, allowing a shell environment or CI/CD secret store to supply the actual value. This parallels our Week 9 use of Kubernetes Secrets for sensitive configuration.

We confirmed that configuration injection was working during the exercise. We deliberately omitted `currency` from our test requests, but both `serverless invoke local` and the HTTP `curl` request returned `"currency":"KES"`. The value therefore came from `process.env.DEFAULT_CURRENCY`, which Serverless populated from the `provider.environment` configuration.

## Question 4

**A cold start adds 200ms to 2 seconds on the first invocation after an idle period. Nia said the 800ms synchronous delay was unacceptable. Why does moving receipt generation to a serverless function solve Nia's problem even if the function has a cold start, and what architectural change makes the cold start irrelevant to the customer experience?**

Moving receipt generation to a serverless function solves Nia's problem because the important architectural change is not simply replacing a container with a function. It is **decoupling receipt generation from the synchronous payment request**.

Previously, `kk-payments` called receipt generation synchronously, so the customer had to wait approximately 800ms for receipt generation before the payment response could complete. In the planned serverless architecture, `kk-payments` will emit a receipt event and the receipt function will process that event separately. The payment service therefore does not need to wait for receipt generation to finish before responding to the customer.

A real cloud function could experience a cold start of approximately 200ms to 2 seconds after being idle. However, that delay occurs in the asynchronous receipt-processing path rather than the customer-facing payment path. The customer therefore does not wait for the function's cold start.

During Monday's exercise we used `serverless-offline`, so our local execution times are not evidence of real cold-start performance. The local Node.js process remains running, whereas actual cold starts occur when a cloud provider has released an idle function runtime and must create a new one.
:::
