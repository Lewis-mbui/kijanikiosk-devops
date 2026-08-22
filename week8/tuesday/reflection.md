# Week 8 Tuesday Reflection

## Question 1: The Layer Deletion Trick Explained

Deleting build tools later in the same Dockerfile stage does not remove them from the image’s earlier layers. Docker builds an image as a sequence of immutable layers. Each instruction such as `RUN`, `COPY`, or `ADD` creates a new layer containing the filesystem changes made by that instruction.

For example, suppose an earlier layer runs `npm ci`. That layer stores both production and development dependencies, including TypeScript, Jest, and ESLint. A later instruction such as:

```dockerfile
RUN npm run build && rm -rf node_modules && npm ci --only=production
```

creates another layer that records the deletion of the original `node_modules` directory and the installation of production dependencies. However, the development dependencies still physically exist inside the earlier `npm ci` layer. The later layer only hides them from the final merged filesystem view. Because Docker retains all layers required to reconstruct the image, their data still contributes to the final image size.

Multi-stage builds avoid this problem by creating a separate final image stage. The builder stage may contain compilers, tests, source code, and development dependencies, but the production stage copies only the required artifacts, such as `dist`, `package.json`, and production dependencies. The builder layers are therefore not part of the final production image.

## Question 2: The `start-period` Parameter

The `--start-period=15s` setting creates an initial grace period during which failing health checks do not count toward the configured `--retries=3` failure threshold. However, the exact outcome also depends on the health-check interval.

Our Dockerfile uses:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3
```

The new version takes 25 seconds to become ready. Under this exact configuration, Docker normally performs the first regular health check after approximately 30 seconds. By that time, the 25-second warm-up has completed, so the first check should pass. Therefore, no failures would normally be recorded and the container would not become unhealthy, even though the start period is shorter than the warm-up time.

The risk becomes real when health checks run before the application is ready, for example with a shorter interval. Failures during the first 15 seconds would be ignored. Failures after 15 seconds would count. Docker would mark the container unhealthy after three consecutive counted failures.

Kubernetes does not normally use a Dockerfile `HEALTHCHECK` directly as a readiness probe. Kubernetes readiness is configured explicitly using `readinessProbe`, while slow startup should usually be handled with a `startupProbe`. In a platform that translated the Docker health check into readiness, premature failures could remove the pod from service endpoints, preventing it from receiving traffic. If repeated restarts were also configured, the deployment could enter a failure cycle even though the application only needed more startup time.

## Question 3: Why Non-Root Matters for `kk-payments` Specifically

Running `kk-payments` as a non-root user is especially important because it processes financial transactions. A vulnerability in the application, one of its dependencies, or its request-handling logic could allow an attacker to execute commands inside the container. The permissions available to that attacker would then match the permissions of the application process.

If the container runs as root, the attacker may be able to modify application files, replace executables, change configuration, install additional tools, read protected files, alter logs, or create persistence inside writable parts of the container. A container escape vulnerability would also be more dangerous when the compromised process begins with root privileges. For a payments service, these actions could affect transaction integrity, audit evidence, credentials, or service availability.

When the service runs as `kijani`, the attacker is restricted to the files and actions permitted to that user. This does not make the container completely secure, but it reduces the impact of successful code execution.

The ownership change is a necessary companion to `USER kijani`. Files copied into an image are normally owned by root. Without:

```dockerfile
RUN chown -R kijani:kijani /app
```

the application may be unable to access files or directories that it needs to read or write. Changing the user without assigning appropriate ownership can therefore break the service. The goal is to give `kijani` only the access required to run the application, rather than giving the whole process root privileges.

## Question 4: The Builder Stage in the CI Pipeline

The CI pipeline should run tests against the builder stage, not the production stage. The builder contains the source files, test files, TypeScript compiler, Jest, `ts-jest`, ESLint, and all development dependencies. The production stage intentionally excludes these tools and contains only the compiled application and runtime dependencies. Running tests against the production stage would either fail because Jest is absent or require adding development tools back into the runtime image, defeating the purpose of the multi-stage build.

For the test step, Jenkins should build the builder target:

```bash
docker build \
  -f Dockerfile.production \
  --target builder \
  -t kijanikiosk/kk-payments:${VERSION}-builder .
```

It should then run the tests inside that image:

```bash
docker run --rm \
  kijanikiosk/kk-payments:${VERSION}-builder \
  npm test
```

For the publish step, Jenkins should build the final production stage without `--target builder`:

```bash
docker build \
  -f Dockerfile.production \
  -t ${REGISTRY}/kijanikiosk/kk-payments:${VERSION} .
```

The production image can then be authenticated, pushed to the registry, and deployed.

The Week 5 Jenkinsfile would therefore change in three main places. First, the existing host-based `npm test` step would be replaced with a builder-stage Docker build. Second, the tests would run using `docker run` against that builder image. Third, the image publication stage would build and push the final production image separately. This ensures that CI tests the application in the same controlled build environment while keeping development dependencies out of the deployable image.
