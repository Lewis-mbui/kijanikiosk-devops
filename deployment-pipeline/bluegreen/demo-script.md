# KijaniKiosk Blue/Green Deployment Demonstration Script

## Introduction

"Today I'll demonstrate how KijaniKiosk deploys a new version of the application without interrupting users. The system keeps two copies of the application running at the same time: one currently serving customers and another ready to receive the next release."

---

## Step 1 – Current Production

"At the moment, the blue environment is serving all user traffic. The green environment is already running the new version in the background but is not receiving any customer requests. Before making any change, we confirm that both environments are healthy."

---

## Step 2 – Traffic Switch

"Instead of stopping the running application and replacing it, we simply instruct Nginx to send new requests to the green environment. Because both versions are already running, users continue accessing the application without experiencing downtime."

---

## Step 3 – Continuous Monitoring

"Switching traffic is not the final step. For the next two minutes, an automated monitor checks the application's health every five seconds. It verifies that requests are succeeding, response times remain acceptable, and no unusual error patterns appear."

---

## Step 4 – Simulated Failure

"To demonstrate the recovery process, we intentionally stop the green application. The monitoring system immediately begins detecting failed health checks. After confirming that the failures are consistent rather than temporary, it automatically starts the rollback process."

---

## Step 5 – Automatic Rollback

"The rollback returns traffic to the previously verified blue environment. Because the earlier version is still running, service is restored almost immediately without requiring an engineer to manually intervene."

---

## Business Value

"This deployment approach reduces the risk associated with releasing new software. New versions can be deployed with minimal disruption, unhealthy releases are detected automatically, and recovery happens quickly. As a result, customers experience higher service availability while engineers can deploy updates with greater confidence."

---

## Conclusion

"Today's demonstration shows the complete deployment lifecycle: prepare a new version, verify its health, switch traffic safely, monitor the deployment, and automatically recover if a problem is detected. This process helps KijaniKiosk deliver software reliably while protecting users from failed releases."
