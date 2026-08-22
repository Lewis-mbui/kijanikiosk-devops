# KijaniKiosk Payments Pipeline - Fault Injection Log

## Purpose

This document records the deliberate failures introduced into the Jenkins pipeline to verify that each stage behaves predictably and that the configured post conditions execute correctly.

Each fault was introduced individually, observed, and then restored before testing the next stage.

| Stage Faulted | Fault Introduced                                                             | Expected Behaviour                                                                               | Observed                                                                                                                                                                                      |
| ------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lint          | Added an unused variable to trigger the `no-unused-vars` ESLint rule.        | Build, Verify, Archive, and Publish should all be skipped.                                       | **Yes.** Lint failed immediately, all downstream stages were skipped, workspace cleanup executed, and the failure post actions ran.                                                           |
| Build         | Replaced the build command, resulting in no `dist` directory being produced. | Verify, Archive, and Publish should be skipped because no build output exists.                   | **Yes.** Lint passed, Build failed during output verification, all downstream stages were skipped, cleanup and failure post actions executed.                                                 |
| Test (Verify) | Added a deliberately failing Jest assertion.                                 | Security Audit should still complete, Verify should fail, Archive and Publish should be skipped. | **Yes.** Test failed while Security Audit completed successfully. Verify failed overall and downstream stages were skipped. JUnit results were still published.                               |
| Publish       | Changed the Jenkins credential ID from `nexus-credentials` to `wrong-id`.    | Archive should complete successfully, but publishing to Nexus should fail.                       | **Yes.** Archive completed and the artifact remained available in Jenkins. Publish failed because Jenkins could not find the specified credential. Cleanup and failure post actions executed. |

## Summary

The pipeline behaved predictably under every injected failure. Earlier stages prevented unnecessary downstream execution, parallel verification continued to provide diagnostic information, and post actions consistently cleaned the workspace and reported failures.
