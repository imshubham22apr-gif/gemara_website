---
layout: page
title: Enforcement Log Guide
description: Step-by-step guide to creating Gemara-compatible Enforcement Logs (Layer 6)
---

## What This Is

This guide walks through creating an **Enforcement Log** using the [Gemara](https://gemara.openssf.org/) project. The document conforms to `#EnforcementLog` in [enforcementlog.cue](https://github.com/gemaraproj/gemara/blob/main/enforcementlog.cue) and the published [Enforcement Log schema](https://gemara.openssf.org/schema/enforcementlog.html). Examples use `gemara-version: "1.6.0"` to match the [v1.6.0](https://github.com/gemaraproj/gemara/releases/tag/v1.6.0) release.

**The basic idea:** While **Evaluation Logs (Layer 5)** capture findings and whether checks passed or failed, an **Enforcement Log (Layer 6)** documents the concrete actions executed when non-compliance or policy deviations occur. It records who or what acted, what steps were performed, which policy authorized the remediation or quarantine, and the exact evaluation findings that triggered the action.

---

## Key Concepts

- **Target (`target`):** The exact system, workload, or service upon which enforcement was enacted.
- **Disposition (`disposition`):** The aggregate enforcement state (`Enforced`, `Tolerated`, `Clear`, or `Undetermined`).
- **Actions (`actions`):** A list of enforcement actions performed, including:
  - `start` / `end` timestamps.
  - `method`: Reference to the accepted enforcement mechanism defined in an upstream Policy (Layer 3).
  - `steps`: Addressable audit trail of code paths or scripts invoked (e.g. `isolate-network-namespace`).
  - `justification`: Links back to the triggering findings in an Evaluation Log (Layer 5) and any applicable approved exceptions.

---

## Step 1: Define Metadata and Mapping References

Declare the top-level artifact metadata, target system, and references to upstream evaluation logs and policies:

```yaml
metadata:
  id: "enf-log-slam-cm-001"
  type: "EnforcementLog"
  gemara-version: "1.6.0"
  version: "1.0.0"
  description: "Enforcement actions executed against container management tools following security evaluation findings."
  author:
    id: "sec-ops-automation"
    name: "Security Operations Automated Enforcement Engine"
    type: "Software"
  mapping-references:
    - id: "EVAL-LOG"
      title: "Container Security Evaluation Log"
      version: "1.0.0"
      url: "https://example.com/evaluations/eval-log-slam-cm-001.yaml"
    - id: "ORG-POLICY"
      title: "Information Security Policy for Cloud and Web Applications"
      version: "1.0.0"
      url: "https://example.com/policies/org-policy-001.yaml"
target:
  id: "svc-container-mgmt-worker-01"
  name: "Container Management Worker Node"
  type: "Software"
  environment: "production"
  owner:
    name: "Platform Infrastructure Team"
    email: "platform-infra@example.com"
disposition: "Enforced"
```

---

## Step 2: Record Actions and Justification

Each action captures the automated or manual intervention, referencing the policy method and the evaluation log entry:

```yaml
actions:
  - disposition: "Enforced"
    message: "Quarantined container execution engine due to unmitigated privileged container escape risk (evaluation finding Failed)."
    start: "2026-11-10T14:30:00Z"
    end: "2026-11-10T14:30:15Z"
    method:
      reference-id: "ORG-POLICY"
      entry-id: "rule-disallow-privileged"
      remarks: "Enforces automated quarantine action defined under Policy section rule-disallow-privileged."
    steps:
      - "drain-workload-node:worker-01"
      - "revoke-cluster-credentials"
      - "isolate-network-namespace"
    justification:
      assessments:
        - result: "Failed"
          log:
            reference-id: "EVAL-LOG"
            entry-id: "eval-slam-cm-chk-01"
            remarks: "Privileged container flag detected on workload in production environment."
```

---

## Step 3: Validate with CUE

Validate against the `#EnforcementLog` schema using CUE:

```bash
cue vet -c -d '#EnforcementLog' github.com/gemaraproj/gemara@v1.6.0 your-enforcement-log.yaml
```

If your disposition is `Clear`, CUE verifies that all justified evaluation results are `Passed`. If non-compliant actions occurred without valid exceptions, schema checks alert on missing or inconsistent fields.

---

## Complete Example

A complete, schema-valid example is available in [enforcement-log-example.yaml](enforcement-log-example.yaml).
