## Reflection Question 1: Docker Layer Caching

When I changed only `src/payments.ts` and rebuilt the image, Docker reused the cached layers for the base image, working directory, package manifest copy, and dependency installation. The instructions `FROM node:18-alpine`, `WORKDIR /app`, `COPY package.json package-lock.json ./`, and `RUN npm ci` did not need to run again because neither the base image nor the dependency files had changed.

The first cache miss occurred at:

```dockerfile
COPY . .
```

This layer changed because the TypeScript source file had been modified. Once this layer changed, Docker also reran:

```dockerfile
RUN npm run build
```

because the TypeScript source needed to be recompiled into the `dist/` directory.

If I changed `package.json` or `package-lock.json`, the cache would be invalidated earlier at the package copy layer. Docker would then rerun `npm ci`, copy the application source again, and rerun the TypeScript build. This is why dependency files are copied before the rest of the source code: normal source changes do not force Docker to reinstall every dependency.

## Reflection Question 2: Tarball Deployment vs Container Deployment

In the Week 7 tarball deployment, the application artifact depended heavily on the target server environment. The deployment assumed that Node.js and npm were already installed, that the expected directory structure existed under `/opt/kijanikiosk`, that service users and permissions had been configured, and that systemd unit files were available to start and manage the application. Ansible and the deployment scripts were responsible for preparing these operating system requirements.

The Docker image replaces many of these assumptions by packaging the application runtime and filesystem together. The `FROM node:18-alpine` instruction provides the Node.js runtime. `WORKDIR /app` defines the application directory. `COPY` places the source and package files into that directory, while `RUN npm ci` installs the dependencies. `RUN npm run build` compiles the TypeScript source into JavaScript, and `CMD ["node", "dist/index.js"]` defines how the application starts.

The host still needs Docker, networking, storage, and appropriate security configuration, but it no longer needs to be manually prepared with the exact Node.js version or application directory structure. This makes the deployment environment more consistent because the same image can be run on different Docker hosts with the same application runtime and dependencies.

## Reflection Question 3: CMD Exec Form vs Shell Form

Using the exec form:

```dockerfile
CMD ["node", "dist/index.js"]
```

starts the Node.js application directly as the container's main process. This means Node receives operating system signals such as `SIGTERM` directly when the container is stopped.

Using a command such as:

```dockerfile
CMD ["npm", "start"]
```

introduces npm as the main container process. npm then starts Node as a child process. This extra process can interfere with signal handling because the shutdown signal is sent to npm first and may not be forwarded reliably to the Node.js application.

In this project, `src/index.ts` registers handlers for `SIGTERM` and `SIGINT`. When the container is stopped, the compiled Node.js application receives the signal, stops accepting new requests, closes the HTTP server, and exits cleanly. This behaviour was visible when the container logged the graceful shutdown messages.

Graceful shutdown is particularly important for a payment service. The application may be processing active requests when a deployment or container stop occurs. Giving the server time to close properly reduces the risk of interrupting requests, leaving operations incomplete, or returning unnecessary failures to clients. The exec form therefore provides more reliable process management and shutdown behaviour.
