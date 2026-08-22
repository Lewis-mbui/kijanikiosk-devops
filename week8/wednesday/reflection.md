# Week 8 Wednesday Reflection

## Question 1: The Semver-SHA Tag and Rollback

To roll back from `1.0.0-d9e1f4a` to `1.0.0-a3f2c8b`, the Kubernetes Deployment manifest is updated by changing only the image tag. For example, the image field changes from `kk-payments:1.0.0-d9e1f4a` to `kk-payments:1.0.0-a3f2c8b`. The updated manifest is then applied using `kubectl apply -f deployment.yaml`. Kubernetes compares the desired state with the running state and performs a rolling update, gradually replacing Pods running the faulty image with Pods using the previous image.

This differs from the Week 7 rollback mechanism. During Week 7, the application already existed on both the blue and green environments, and the rollback consisted of running `rollback.sh`, which changed the active nginx upstream and redirected traffic back to the previously deployed version. The application binaries did not need to be downloaded again because they already existed on the server. In Kubernetes, the rollback is image-based rather than server-based. The Deployment is updated to reference a previous immutable image tag, and Kubernetes pulls that image from the registry if necessary before replacing the existing Pods. Both approaches achieve the same objective of restoring a known-good version, but Week 7 switches traffic between existing deployments while Kubernetes changes the desired image version and recreates the running Pods.

---

## Question 2: The ImagePullSecret Lifecycle

When the GitHub Personal Access Token expires after 90 days, the first step is to create a new token in the registry provider with the required package permissions. Next, the Kubernetes ImagePullSecret must be updated to contain the new credentials, either by recreating the Secret or replacing it with a new version using `kubectl`. Once the Secret has been updated, any newly created Pods can authenticate successfully and pull images from the private registry again.

The Deployment manifest does not need to change. It continues to reference the same Secret name, `kijani-registry-credentials`, through the `imagePullSecrets` field. The reference remains valid even though the underlying credential has changed.

This closely matches the credential rotation process from Week 5. In Jenkins, the Nexus password could be rotated by updating the credential stored in the Jenkins credentials store while leaving the Jenkinsfile unchanged because it referenced only the `credentialsId`. Kubernetes follows the same principle. The manifest references the Secret by name, while the credential value is managed separately inside Kubernetes. Separating the reference from the secret value allows credentials to be rotated without modifying or recommitting deployment manifests.

---

## Question 3: The latest Tag in CI Pipelines

Using the `latest` tag as the primary deployment tag introduces ambiguity because it is mutable. During a Kubernetes rolling update, different nodes may pull the `latest` image at different times. One node may already have an older cached version while another retrieves the newly pushed image, resulting in Pods running different application versions even though the Deployment manifest references the same tag. This makes deployments difficult to reproduce, complicates debugging, and removes the certainty required for reliable rollbacks.

The semver-SHA strategy avoids this problem because every build produces a unique and immutable tag that identifies one specific image. A Deployment always references exactly one version, making every rollout and rollback deterministic.

Tagging an image as `latest` in addition to the immutable semver-SHA tag is acceptable only as a convenience for developers during local development or testing. Production deployments should continue to reference the immutable semver-SHA tag. The important precaution is that Kubernetes manifests, CI/CD pipelines, and production automation must never depend on `latest`; they should always deploy the explicit versioned tag.

---

## Question 4: Registry, Nexus, and the Delivery Pipeline

Nexus and the container registry serve different but complementary roles in the delivery pipeline. Nexus stores the packaged application artifact as an npm tarball, while the container registry stores the complete Docker image that will eventually be deployed to Kubernetes.

The npm tarball is superseded during the Docker build process. In a multi-stage build, the builder stage retrieves or installs the application, builds it, and produces the production-ready output. The runtime stage copies only the files required to run the application into the final image. After the image has been built and pushed to the container registry, Kubernetes no longer deploys the npm tarball directly. Instead, it deploys the Docker image that already contains the application and its runtime environment.

This does not make Nexus irrelevant. Nexus continues to provide versioned, immutable storage for application artifacts and remains valuable for dependency management, package distribution, and earlier stages of the CI pipeline. The container registry becomes the deployment artifact store, while Nexus remains the package artifact store. The Docker image effectively packages the application artifact together with its operating system environment and runtime, making the container image the artifact consumed by Kubernetes.
