# MASCORE-20742 — Suite and Manage Resource DR POC: Evidence Audit & Results

Legend:
- **VERIFIED (Direct Evidence):** Established directly by repository file paths, Helm templates, Kustomize overlays, or CLI commands cited with exact line references.
- **PROBABLE (Inferred / Architectural):** Deduced from Kubernetes operator reconciliation patterns, controller roles, and configuration schemas; subject to live cluster confirmation.
- **UNRESOLVED:** Requires lead architectural sign-off, security standard approval, or isolated-cluster execution.

---

## 1. Executive Summary for Lead

This document presents the disaster recovery (DR) resource audit for **MAS Suite (`Suite/inst03`)** and **Manage (`ManageWorkspace/inst03-main`)** under Jira story MASCORE-20742. It establishes exact resource origins, recovery stages, and backup classifications organized by Kubernetes resource type, clearly separating verified repository facts from inferred runtime behavior.

### High-Level Summary
1. **Scope:** The recovery targets are only `Suite/inst03` in `mas-inst03-core` and `ManageWorkspace/inst03-main` in `mas-inst03-manage`. Shared services are dependency references only, not a full-cluster inventory.
2. **Ambiguous Resource Audit (21 Items Reassessed):**
   - **14 resources VERIFIED:** Both source templates/definitions and deterministic GitOps/ArgoCD management are directly verified in repository code.
   - **7 resources PROBABLE:** Source definitions, catalog dependencies, or RBAC roles are verified in files, but runtime controller creation and automatic adoption/reconciliation behavior remain inferred architectural deductions.
   - **0 resources remain with unmapped origin or unknown classification.**
3. **Current analysis set (55 distinct resource records, including dependency records):**
   - **Secrets (21):** 4 Mandatory State Restores, 2 Conditional Continuity Restores, 1 Opt-in Safeguard Restore, 3 Day 0 Prerequisites, 7 GitOps/AVP References, 1 Ephemeral CI Hook Secret, 2 Held Behind CA Policy (11 Verified, 8 Probable, 2 Unresolved).
   - **Custom Resources (7):** 2 Primary CRs (`Suite`, `ManageWorkspace`), 5 Core Dependency CRs (`BasCfg`, `GenericAddon`, `JdbcCfg`, `MongoCfg`, `SlsCfg`) (7 Verified).
   - **Subscriptions (5):** 3 GitOps Subscriptions (`ibm-mas-operator`, `ibm-mas-manage-operator`, `cert-manager`), 2 OLM Package Dependencies (`ibm-truststore-mgr` core/manage) (3 Verified, 2 Probable).
   - **OLM Resources (7):** 2 OperatorGroups, 4 ClusterServiceVersions, 1 CatalogSource (`ibm-operator-catalog`) (5 Verified, 2 Probable).
   - **ConfigMaps (5):** 1 Runtime Licensing Cache (`metering-sls-entitlement`), 2 Reconcile/Status Maps, 2 Truststore Runtime Maps (2 Verified, 3 Probable).
   - **Other Relevant Resources (10):** 4 Namespaces, 2 CA Certificates, 2 Issuers, 2 ClusterIssuers (10 Verified).
   - **Analysis-set total:** **38 VERIFIED, 15 PROBABLE, 2 UNRESOLVED (55 records including dependency records; not the in-scope namespace-only count).**
4. **Actionable Disaster Recovery Guidance:**
   - **Mandatory DR Backup (4 State Secrets):** `inst03-credentials-superuser`, `inst03-keys-jwt` (standard core discovered item outside the 21 ambiguous items), `main-manage-encryption-secret`, `main-manage-encryption-secret-operator`.
   - **Recommended Conditional Continuity Backup (2 Secrets):** `inst03-keys-ltpa` (in `core` and `manage`) — backed up to avoid anticipated invalidation of active SSO cookies/sessions (`LtpaToken2`).
   - **Opt-in Safeguard Backup (1 Secret):** `inst03-main-jdbccfg-workspace-application-binding` — while expected to be operator-recreated from `JdbcCfg`, pre-restoring is a proposed safeguard against container startup race conditions during slow operator reconciles.
   - **Proposed Backup Exclusions (`mode=reference`):** All GitOps CRs, AWS-backed connection secrets, OLM Subscriptions, and runtime bindings/caches (`inst03-coreidp-system-binding`, `metering-sls-entitlement`).
5. **Prerequisite Lifecycle Separation:**
   - **Day 0 Cluster Prerequisites (3 AWS SM items):** `aws` (`mas-inst03-syncres`), `ibm-entitlement` (`mas-inst03-core` and `mas-inst03-manage`).
   - **Day 1 Instance Prerequisites (5 AWS SM + 2 GitOps Values):** Mongo, JDBC, DRO, SLS, COS logging, and Additional Server Config XMLs.
   - **CI / Test Pipeline Hooks (1 transient hook Secret):** `pre-jreporter-...-devopsuri` (PreSync hook created only during test execution with `.Values.devops_mongo_uri`).

| Capability | Status | Notes |
|---|---|---|
| Ambiguous resource audit | **VERIFIED** | 21/21 ambiguous items mapped (14 Verified, 7 Probable) |
| Scoped recovery inventory | **VERIFIED** | 55 distinct resources categorized by Kubernetes type |
| Backup hardening & validation | **VERIFIED** (offline) | 96 unit tests passing; SHA256SUMS and manifest verification |
| Multi-stage Recovery Planner | **VERIFIED** (offline) | Deterministic 7-stage topological ordering |
| Guarded restore tool | **VERIFIED** (mocked `oc`) | Safety guards prevent execution against source cluster |
| Backup encryption standard | **UNRESOLVED** | Gated behind `DR_ENCRYPT_CMD`; requires platform team standard |
| CA key continuity policy | **UNRESOLVED** | Requires Suite architecture lead decision (Options A, B, or C) |
| Isolated live cluster restore | **UNRESOLVED** | Blocked on encryption standard & isolated cluster availability |

---

## 2. Scope (lead-aligned)

### 2.1 In-scope targets — only these two namespaces
- **MAS Suite:** `Suite/inst03` in `mas-inst03-core`.
- **MAS Manage:** `ManageWorkspace/inst03-main` in `mas-inst03-manage`.

The inventory and recovery decision must be organized by the agreed resource categories: **Secrets, Custom Resources (CRs), Subscriptions, OLM resources, ConfigMaps, Certificates, and other resources**. Resource ownership and recovery method are recorded per item.

### 2.2 Dependency references (not a full-cluster inventory)
Some in-scope resources refer to dependencies outside these two namespaces, such as cert-manager issuers/CA material, the `mas-inst03-syncres` AWS credential, or an OLM CatalogSource. Record those only as **external prerequisites/dependency references** needed to explain recovery. Do not recursively inventory or claim DR coverage for the entire `cert-manager`, `mas-inst03-syncres`, `openshift-marketplace`, or cluster.

### 2.3 Explicit exclusions
- Other MAS instances and unrelated namespaces.
- General cluster-wide resources and unrelated operators.
- Database contents and database backup/restore, which are handled by separate stories.
- A dependency outside `mas-inst03-core` / `mas-inst03-manage` is not considered backed up merely because its name or reference appears in this POC.

### Scope/evidence caveat
The 55-object analysis below includes a small set of shared dependency records for explaining prerequisites. It must **not** be represented as a 55-object inventory limited exclusively to the two target namespaces. Before claiming a final live inventory count, run discovery against the target cluster and report counts separately for (a) objects in the two target namespaces and (b) external dependency references. Timeout or permission notes make discovery partial, not authoritative.

---

## 3. Inventory by Kubernetes Resource Type (55 Distinct Resources)

### 3.1 Secrets (21 Items)

| # | Secret Name | Namespace | Association | Creator / Source of Truth | Source Repo & File Path | Recovery Method | Backup Requirement | Evidence Level |
|---|---|---|---|---|---|---|---|---|
| 1 | `inst03-credentials-superuser` | `mas-inst03-core` | Suite | Suite Operator / Initial Admin | Standard Suite state secret | `backup_restore_pre_reconcile` (Stage 4) | **Mandatory DR Backup** (`mode=restore`) | **VERIFIED** (Metadata) / **PROBABLE** (Adoption) |
| 2 | `inst03-keys-jwt` | `mas-inst03-core` | Suite | Suite Operator | Standard Suite state secret (`ownerReferences: Suite/inst03`) | `backup_restore_pre_reconcile` (Stage 4) | **Mandatory DR Backup** (`mode=restore`) | **VERIFIED** (Metadata) / **PROBABLE** (Adoption) |
| 3 | `main-manage-encryption-secret` | `mas-inst03-manage` | Manage | Manage Operator | Standard Manage state secret (`ownerReferences: ManageWorkspace/inst03-main`) | `backup_restore_pre_reconcile` (Stage 4) | **Mandatory DR Backup** (`mode=restore`) | **VERIFIED** (Metadata) / **PROBABLE** (Adoption) |
| 4 | `main-manage-encryption-secret-operator` | `mas-inst03-manage` | Manage | Manage Operator | Standard Manage state secret (`ownerReferences: ManageWorkspace/inst03-main`) | `backup_restore_pre_reconcile` (Stage 4) | **Mandatory DR Backup** (`mode=restore`) | **VERIFIED** (Metadata) / **PROBABLE** (Adoption) |
| 5 | `inst03-keys-ltpa` | `mas-inst03-core` | Suite | Suite Operator (`ltpakeygenerator`) | `Suite` CR config ([`gitops-envs: ibm-mas-suite.yaml:287`](../../../gitops-envs/fyre-noble8-dev/noble8/inst03/ibm-mas-suite.yaml:287)) | `backup_restore_pre_reconcile` (Stage 4) or operator regenerate | **Recommended Continuity Backup** (`mode=restore`, opt) | **VERIFIED** (Source) / **PROBABLE** (Adoption) |
| 6 | `inst03-keys-ltpa` | `mas-inst03-manage` | Manage | Manage Operator (`mas.util.bind`) | Synced from `mas-inst03-core` | `backup_restore_pre_reconcile` (Stage 4) or operator sync | **Recommended Continuity Backup** (`mode=restore`, opt) | **VERIFIED** (Source) / **PROBABLE** (Adoption) |
| 7 | `inst03-main-jdbccfg-workspace-application-binding` | `mas-inst03-manage` | Manage | MAS Core `internalapi` | Runtime API binding ([`gitops-envs: ibm-mas-masapp-configs.yaml:15`](../../../gitops-envs/fyre-noble8-dev/noble8/inst03/ibm-mas-masapp-configs.yaml:15)) | `recreate_operator` (Stage 6/7) | **Opt-in Safeguard Backup** (`mode=restore_optin`) | **VERIFIED** (Source) / **PROBABLE** (Runtime) |
| 8 | `inst03-coreidp-system-binding` | `mas-inst03-manage` | Manage | MAS Core `internalapi` | Runtime API binding ([`gitops: 05-ibm-mas_essential_rbac.yaml:20`](../../instance-applications/500-540-ibm-mas-suite-app-install/templates/05-ibm-mas_essential_rbac.yaml:20)) | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **VERIFIED** (RBAC) / **PROBABLE** (Runtime) |
| 9 | `system-mongo-credentials` | `mas-inst03-core` | Suite | GitOps + AVP | [`gitops: 01-mongo-credentials_Secret.yaml`](../../instance-applications/130-ibm-mas-mongo-config/templates/01-mongo-credentials_Secret.yaml:1) | `gitops_resync_with_external_secret` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 10 | `inst03-jdbc-wsapp-main-manage-credentials` | `mas-inst03-core` | Suite / Manage | GitOps + AVP | [`gitops: 01-suite_jdbccfg.yaml`](../../instance-applications/130-ibm-jdbc-config/templates/01-suite_jdbccfg.yaml:1) | `gitops_resync_with_external_secret` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 11 | `inst03-bas-system-credentials` | `mas-inst03-core` | Suite | GitOps + AVP | [`gitops: 01-dro-api-token_Secret.yaml`](../../instance-applications/130-ibm-mas-bas-config/templates/01-dro-api-token_Secret.yaml:1) | `gitops_resync_with_external_secret` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 12 | `inst03-sls-system-credentials` | `mas-inst03-core` | Suite | GitOps + AVP | [`gitops: 05-ibm-mas_SlsCfg.yaml`](../../instance-applications/130-ibm-mas-sls-config/templates/05-ibm-mas_SlsCfg.yaml:1) | `gitops_resync_with_external_secret` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 13 | `cos-logging` | `mas-inst03-manage` | Manage | GitOps + AVP | AWS Secrets Manager reference in `gitops-envs` | `gitops_resync_with_external_secret` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 14 | `main-manage-d--sb0--asc--sn` | `mas-inst03-manage` | Manage | GitOps (ArgoCD) | [`gitops: 01-ibm-manage_additional_server_config_secrets.yaml`](../../instance-applications/510-550-ibm-mas-suite-app-config/templates/01-ibm-manage_additional_server_config_secrets.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 15 | `main-manage-d--sb1--asc--sn` | `mas-inst03-manage` | Manage | GitOps (ArgoCD) | [`gitops: 01-ibm-manage_additional_server_config_secrets.yaml`](../../instance-applications/510-550-ibm-manage_additional_server_config_secrets.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 16 | `ibm-entitlement` | `mas-inst03-core` | Suite | Toolchain / AWS SM | `arn:aws:secretsmanager:...:ibm_entitlement` | `gitops_resync_with_external_secret` (Stage 0/1) | Day 0 Prerequisite (`mode=reference`) | **VERIFIED** |
| 17 | `ibm-entitlement` | `mas-inst03-manage` | Manage | Toolchain / AWS SM | `arn:aws:secretsmanager:...:ibm_entitlement` | `gitops_resync_with_external_secret` (Stage 0/1) | Day 0 Prerequisite (`mode=reference`) | **VERIFIED** |
| 18 | `aws` | `mas-inst03-syncres` | Shared | Toolchain / AWS SM | `arn:aws:secretsmanager:...:aws` | `gitops_resync_with_external_secret` (Stage 0/1) | Day 0 Prerequisite (`mode=reference`) | **VERIFIED** |
| 19 | `pre-jreporter-...-devopsuri` | `mas-inst03-manage` | Manage (CI) | Test Hook / AWS SM | [`gitops: 00-presync-report-starter.yaml:10`](../../sub-charts/junitreporter/templates/00-presync-report-starter.yaml:10) | Rendered during CI hook execution | Ephemeral Hook Secret (`none`) | **VERIFIED** |
| 20 | `inst03-cert-internal-ca` | `cert-manager` | Suite | Cert-Manager | Suite CA key pair Secret (`tls.key`, `tls.crt`) in `cert-manager` | Regenerated or restored | Held behind CA Policy (`mode=blocked_ca_key`) | **UNRESOLVED** |
| 21 | `inst03-cert-public-ca` | `cert-manager` | Shared | Cert-Manager | Public CA key pair Secret (`tls.key`, `tls.crt`) in `cert-manager` | Regenerated or restored | Held behind CA Policy (`mode=blocked_ca_key`) | **UNRESOLVED** |

---

### 3.2 Custom Resources (7 Items)

| # | CR Name | Kind | Namespace | Association | Creator / Source of Truth | Source Repo & File Path | Recovery Method | Backup Requirement | Evidence Level |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `inst03` | `Suite` | `mas-inst03-core` | Suite | GitOps (ArgoCD) | [`gitops-envs: ibm-mas-suite.yaml:1`](../../../gitops-envs/fyre-noble8-dev/noble8/inst03/ibm-mas-suite.yaml:1) | `gitops_resync` (Stage 5) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 2 | `inst03-main` | `ManageWorkspace` | `mas-inst03-manage` | Manage | GitOps (ArgoCD) | [`gitops-envs: ibm-mas-masapp-configs.yaml:1`](../../../gitops-envs/fyre-noble8-dev/noble8/inst03/ibm-mas-masapp-configs.yaml:1) | `gitops_resync` (Stage 5) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 3 | `inst03-bas-system` | `BasCfg` | `mas-inst03-core` | Suite | GitOps (ArgoCD) | [`gitops: 03-ibm-mas_BasCfg.yaml`](../../instance-applications/130-ibm-mas-bas-config/templates/03-ibm-mas_BasCfg.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 4 | `inst03-addons-production-database-access` | `GenericAddon` | `mas-inst03-core` | Suite | GitOps (ArgoCD) | [`gitops: 09-production_db_access-cr.yaml`](../../instance-applications/550-ibm-mas-addons-config/templates/09-production_db_access-cr.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 5 | `inst03-jdbc-wsapp-main-manage` | `JdbcCfg` | `mas-inst03-core` | Suite / Manage | GitOps (ArgoCD) | [`gitops: 01-suite_jdbccfg.yaml`](../../instance-applications/130-ibm-jdbc-config/templates/01-suite_jdbccfg.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 6 | `inst03-mongo-system` | `MongoCfg` | `mas-inst03-core` | Suite | GitOps (ArgoCD) | [`gitops: 02-ibm-mas_MongoCfg.yaml`](../../instance-applications/130-ibm-mas-mongo-config/templates/02-ibm-mas_MongoCfg.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 7 | `inst03-sls-system` | `SlsCfg` | `mas-inst03-core` | Suite | GitOps (ArgoCD) | [`gitops: 05-ibm-mas_SlsCfg.yaml`](../../instance-applications/130-ibm-mas-sls-config/templates/05-ibm-mas_SlsCfg.yaml:1) | `gitops_resync` (Stage 3) | Proposed exclusion (`mode=reference`) | **VERIFIED** |

---

### 3.3 Subscriptions (5 Items)

| # | Subscription Name | Namespace | Association | Creator / Source of Truth | Source Repo & File Path | Recovery Method | Backup Requirement | Evidence Level |
|---|---|---|---|---|---|---|---|---|
| 1 | `ibm-mas-operator` | `mas-inst03-core` | Suite | GitOps (ArgoCD) | [`gitops: 100-ibm-mas-suite-operator.yaml`](../../root-applications/ibm-mas-instance-root/templates/100-ibm-mas-suite-operator.yaml:1) | `gitops_resync` (Stage 2) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 2 | `ibm-mas-manage-operator` | `mas-inst03-manage` | Manage | GitOps (ArgoCD) | [`gitops: 500-ibm-mas-masapp-manage-install.yaml`](../../root-applications/ibm-mas-instance-root/templates/500-ibm-mas-masapp-manage-install.yaml:1) | `gitops_resync` (Stage 2) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 3 | `ibm-truststore-mgr` | `mas-inst03-core` | Suite | Suite Operator / OLM | [`cli: mirror/config.py:16`](../../../cli/python/src/mas/cli/mirror/config.py:16) (Package dependency) | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **PROBABLE** |
| 4 | `ibm-truststore-mgr` | `mas-inst03-manage` | Manage | Manage Operator / OLM | [`cli: mirror/config.py:16`](../../../cli/python/src/mas/cli/mirror/config.py:16) (Package dependency) | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **PROBABLE** |
| 5 | `cert-manager` | `cert-manager` | Shared | GitOps (ArgoCD) | [`gitops: 010-ibm-redhat-cert-manager-app.yaml`](../../root-applications/ibm-mas-cluster-root/templates/010-ibm-redhat-cert-manager-app.yaml:1) | `gitops_resync` (Stage 2) | Proposed exclusion (`mode=reference`) | **VERIFIED** |

---

### 3.4 OLM Resources (7 Items — Excluding Subscriptions)

| # | Resource Name | Kind | Namespace | Association | Creator / Source of Truth | Recovery Method | Backup Requirement | Evidence Level |
|---|---|---|---|---|---|---|---|---|
| 1 | `mas-inst03-core-operatorgroup` | `OperatorGroup` | `mas-inst03-core` | Suite | GitOps chart for Suite Operator | `gitops_resync` (Stage 2) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 2 | `mas-inst03-manage-operatorgroup` | `OperatorGroup` | `mas-inst03-manage` | Manage | GitOps chart for Manage Operator | `gitops_resync` (Stage 2) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 3 | `ibm-mas-operator.v*` | `ClusterServiceVersion` | `mas-inst03-core` | Suite | OLM (reconciled from Subscription) | OLM automatic install | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 4 | `ibm-mas-manage.v*` | `ClusterServiceVersion` | `mas-inst03-manage` | Manage | OLM (reconciled from Subscription) | OLM automatic install | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 5 | `ibm-truststore-mgr.v*` | `ClusterServiceVersion` | `mas-inst03-core` | Suite | OLM (reconciled from Subscription) | OLM automatic install | Proposed exclusion (`mode=reference`) | **PROBABLE** |
| 6 | `ibm-truststore-mgr.v*` | `ClusterServiceVersion` | `mas-inst03-manage` | Manage | OLM (reconciled from Subscription) | OLM automatic install | Proposed exclusion (`mode=reference`) | **PROBABLE** |
| 7 | `ibm-operator-catalog` | `CatalogSource` | `openshift-marketplace` | Shared | Cluster setup / GitOps | Pre-existing cluster dependency | Cluster Prerequisite | **VERIFIED** |

---

### 3.5 ConfigMaps (5 Items)

| # | ConfigMap Name | Namespace | Association | Creator / Source of Truth | Source Repo & File Path | Recovery Method | Backup Requirement | Evidence Level |
|---|---|---|---|---|---|---|---|---|
| 1 | `metering-sls-entitlement` | `mas-inst03-core` | Suite | MAS Core licensing service | Runtime SLS API cache (`OpenAPI-Generator`) | `recreate_operator` (Stage 6/7) | Proposed exclusion (Transient cache) | **PROBABLE** |
| 2 | `inst03-suite-reconcile` | `mas-inst03-core` | Suite | Suite Operator | Runtime reconcile status tracking | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 3 | `inst03-main-manage-status` | `mas-inst03-manage` | Manage | Manage Operator | Runtime application status tracking | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **VERIFIED** |
| 4 | `inst03-main-truststore-cfg` | `mas-inst03-manage` | Manage | `ibm-truststore-mgr` | Runtime Truststore config | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **PROBABLE** |
| 5 | `inst03-main-truststore-tsmcfg` | `mas-inst03-manage` | Manage | `ibm-truststore-mgr` | Runtime Truststore config | `recreate_operator` (Stage 6/7) | Proposed exclusion (`mode=reference`) | **PROBABLE** |

---

### 3.6 Other Relevant Resources (10 Items)

*Note on CA Certificates vs CA Secrets:* `Certificate.cert-manager.io/inst03-cert-internal-ca` (below) is the custom resource defining CA issuance parameters; `Secret/inst03-cert-internal-ca` (Section 3.1) is the distinct core `v1/Secret` object generated by cert-manager holding the actual TLS private key and certificate bytes in `cert-manager`.

| # | Resource Name | Kind | Namespace | Association | Creator / Source of Truth | Source Repo & File Path | Recovery Method | Backup Requirement | Evidence Level |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `mas-inst03-core` | `Namespace` | - | Suite | ArgoCD (`CreateNamespace=true`) | [`gitops: 130-ibm-mas-suite-app.yaml:35`](../../root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-app.yaml:35) | `create_namespace` (Stage 1) | Namespace Prerequisite | **VERIFIED** |
| 2 | `mas-inst03-manage` | `Namespace` | - | Manage | ArgoCD (`CreateNamespace=true`) | [`gitops: 500-ibm-mas-masapp-manage-install.yaml:32`](../../root-applications/ibm-mas-instance-root/templates/500-ibm-mas-masapp-manage-install.yaml:32) | `create_namespace` (Stage 1) | Namespace Prerequisite | **VERIFIED** |
| 3 | `mas-inst03-syncres` | `Namespace` | - | Shared | ArgoCD (`CreateNamespace=true`) | [`gitops: 000-ibm-sync-resources.yaml:32`](../../root-applications/ibm-mas-instance-root/templates/000-ibm-sync-resources.yaml:32) | `create_namespace` (Stage 1) | Namespace Prerequisite | **VERIFIED** |
| 4 | `cert-manager` | `Namespace` | - | Shared | ArgoCD (`CreateNamespace=true`) | [`gitops: 010-ibm-redhat-cert-manager-app.yaml:31`](../../root-applications/ibm-mas-cluster-root/templates/010-ibm-redhat-cert-manager-app.yaml:31) | `create_namespace` (Stage 1) | Namespace Prerequisite | **VERIFIED** |
| 5 | `inst03-cert-internal-ca` | `Certificate` | `cert-manager` | Suite | Suite Operator / Cert-Manager | Generated from `Suite` CR config | Recreated by cert-manager | Proposed exclusion | **VERIFIED** |
| 6 | `inst03-cert-public-ca` | `Certificate` | `cert-manager` | Shared | Suite Operator / Cert-Manager | Generated from `Suite` CR config | Recreated by cert-manager | Proposed exclusion | **VERIFIED** |
| 7 | `mas-inst03-core-internal-ca-issuer` | `Issuer` | `cert-manager` | Suite | Suite Operator / Cert-Manager | Generated from `Suite` CR config | Recreated by operator | Proposed exclusion | **VERIFIED** |
| 8 | `mas-inst03-core-public-ca-issuer` | `Issuer` | `cert-manager` | Shared | Suite Operator / Cert-Manager | Generated from `Suite` CR config | Recreated by operator | Proposed exclusion | **VERIFIED** |
| 9 | `mas-inst03-core-internal-issuer` | `ClusterIssuer` | - | Suite | Suite Operator / Cert-Manager | Generated from `Suite` CR config | Recreated by operator | Proposed exclusion | **VERIFIED** |
| 10 | `mas-inst03-core-public-issuer` | `ClusterIssuer` | - | Shared | Suite Operator / Cert-Manager | Generated from `Suite` CR config | Recreated by operator | Proposed exclusion | **VERIFIED** |

---

## 4. Ambiguous Resource Audit Metric (21 Items Reconciled)

The 21 ambiguous items originally flagged during live discovery against `inst03` are reconciled across the resource categories above:

| Ambiguity Group | Count | Resources Included | Verified / Probable Breakdown | Discovery Finding & Origin |
|---|:---:|---|---|---|
| **Group A: GitOps CRs & Secrets** | 8 | `BasCfg`, `GenericAddon`, `JdbcCfg`, `MongoCfg`, `SlsCfg`, and 3 credential Secrets (`bas`, `jdbc`, `mongo`) | 8 VERIFIED | Managed directly by Helm charts in `instance-applications/130-ibm-mas-*-config` with AVP interpolation. Recovered in Stage 3. |
| **Group B: LTPA Secrets** | 2 | `inst03-keys-ltpa` (core and manage) | 2 PROBABLE (Adoption) | Generated by `ltpakeygenerator` service in `Suite` CR. Synced to Manage via `mas.util.bind`. Recommended continuity backup. |
| **Group C: Runtime Bindings & Cache** | 3 | `inst03-coreidp-system-binding`, `inst03-main-jdbccfg-workspace-application-binding`, `metering-sls-entitlement` | 3 PROBABLE (Runtime) | Created by MAS Core `internalapi` at runtime. `inst03-coreidp-system-binding` has VERIFIED RBAC in chart. Proposed backup exclusions / opt-in safeguard. |
| **Group D: Namespaces** | 4 | `mas-inst03-core`, `mas-inst03-manage`, `mas-inst03-syncres`, `cert-manager` | 4 VERIFIED | Created by ArgoCD Application manifests setting `CreateNamespace=true`. Pre-created in Stage 1. |
| **Group E: Truststore Subscriptions** | 2 | `ibm-truststore-mgr` (core and manage) | 2 PROBABLE | Catalog package dependency in `ibm-operator-catalog`. Inferred recreation via OLM dependency mechanism in Stage 6/7. |
| **Group F: Server Config Secrets** | 2 | `main-manage-d--sb0--asc--sn`, `main-manage-d--sb1--asc--sn` | 2 VERIFIED | Rendered by `510-550-ibm-mas-suite-app-config` from Base64 XML in `gitops-envs` values. Recovered in Stage 3. |
| **Total Ambiguous Items Mapped** | **21** | All 21 origins & recovery paths mapped | **14 VERIFIED, 7 PROBABLE, 0 UNRESOLVED** |

---

## 5. Continuity Requirements & Safety Analysis

### 5.1 `inst03-keys-jwt` (Core — Standard Discovered Item Outside 21 Ambiguous Items)
- **Observed Metadata:** Discovered with explicit `ownerReferences` to `Suite/inst03` and matching the state hint pattern. It is tracked as part of the primary restorable state inventory outside the 21 ambiguous items.
- **Function:** Contains RSA signing key pairs used by MAS Core authentication services to sign and verify internal JSON Web Tokens (JWT) for users and service accounts.
- **Anticipated Impact (Inferred):** If excluded from DR restore, the Suite Operator is expected to generate a fresh key pair upon initialization, which would invalidate pre-existing JWT tokens and active API sessions according to standard JWT signature validation. Restoring `inst03-keys-jwt` in Stage 4 prior to Suite reconcile is intended to preserve token signature continuity (**VERIFIED** metadata; **PROBABLE** operator adoption).
- **Audit Conclusion:** **Mandatory DR Backup (`mode=restore`)**.

### 5.2 `inst03-keys-ltpa` (Core & Manage)
- **Observed Metadata:** Created in `-core` by `Suite` CR `ltpakeygenerator` service and synced by Manage Operator to `-manage`.
- **Anticipated Impact (Inferred):** If excluded from backup, operator key regeneration is expected to invalidate active user browser sessions, SSO tokens (`LtpaToken2`), and shared LTPA tokens with external WebSphere systems.
- **Audit Conclusion:** **Should remain conditionally backed up (`mode=restore`, optional)** to ensure seamless session continuity across disaster recovery.

### 5.3 `inst03-main-jdbccfg-workspace-application-binding` (Manage)
- **Observed Metadata:** Created dynamically in `-manage` by `internalapi` from `JdbcCfg`.
- **Anticipated Impact (Inferred):** While dynamically generatable from `JdbcCfg`, if `ManageServerBundle` pods start before `internalapi` completes binding generation on a restored cluster, pods risk entering `CreateContainerConfigError` loops.
- **Audit Conclusion:** Proposed as an **opt-in restore safeguard (`mode=restore_optin`)** to prevent potential pod startup race conditions during slow reconciliations.

---

## 6. Actionable Disaster Recovery Playbook & Staging

Recovery proceeds in 7 deterministic, topologically sorted stages:

1. **Stage 1 (Namespaces & Prerequisites):** Pre-create or verify namespaces (`mas-inst03-core`, `mas-inst03-manage`, `mas-inst03-syncres`, `cert-manager`) and Day 0 Secrets (`aws`, `ibm-entitlement`).
2. **Stage 2 (Operators & OLM):** Deploy OperatorGroups and Subscriptions (`ibm-mas-operator`, `ibm-mas-manage-operator`, `cert-manager`).
3. **Stage 3 (GitOps Dependencies & CRs):** Sync dependency charts for Mongo, JDBC, SLS, DRO/BAS, and Additional Server Config Secrets via ArgoCD with AVP interpolation.
4. **Stage 4 (State-Bearing DR Restoration):** Restore mandatory state secrets (`inst03-credentials-superuser`, `inst03-keys-jwt`, `main-manage-encryption-secret`, `main-manage-encryption-secret-operator`), continuity secrets (`inst03-keys-ltpa`), and opt-in binding safeguards **before** primary CR reconciliation begins.
5. **Stage 5 (Primary CRs):** Apply `Suite/inst03` and `ManageWorkspace/inst03-main` CRs via GitOps.
6. **Stage 6 (Suite Reconcile):** Suite Operator adopts restored secrets, connects to Mongo/SLS/DRO, reconciles internal API, generates CoreIDP binding, and triggers OLM truststore dependencies.
7. **Stage 7 (Manage Reconcile & Pod Startup):** Manage Operator adopts restored encryption keys, binds JDBC/CoreIDP, initializes database schema, and starts Liberty server bundle pods.

---

## 7. Remaining Risks & Required Lead Decisions

1. **CA Key Continuity Policy (Options A, B, or C):**
   - *Option A (Fresh CA):* Exclude CA keys from backup; cert-manager mints fresh internal CAs upon recovery. Requires confirmation that all internal MAS microservices and external clients tolerate CA rotation.
   - *Option B (Encrypted CA Backup):* Back up CA key pairs under strict encryption. Preserves existing certificates without client truststore disruption.
   - *Option C (External CA / KMS):* Store CA private keys in external KMS/Vault.
2. **Approved Backup Encryption Standard (`DR_ENCRYPT_CMD`):**
   - Storage of state secrets and optional CA keys requires platform/security team approval for the symmetric/asymmetric encryption command and key custody architecture.
3. **Isolated-Cluster Validation:**
   - Execute an end-to-end restore dry-run and live apply on a dedicated, isolated test cluster with non-production databases to validate operator secret adoption and container startup behavior.

---

## 8. Audit Verification Commands

```text
$ python3 build/bin/verify_readme_structure.py poc/suite-resource-dr/README.md
Passed: 1, Failed: 0

$ python3 -W error::ResourceWarning -m unittest discover -s poc/suite-resource-dr/tests
Ran 96 tests
OK
```


---

## Suite and Manage Resource Inventory — DR Scope (MASCORE-20742, COT)

> **Status: NOT COMPLETE.** This inventory is repository-verified for *resource definitions*, *namespace rules* and *backup/restore tool lists*. It is **not** verified for what actually exists in the COT clusters, because no COT or standby data exists in any local source (see I-0.2). Every COT/standby row is therefore "can be generated / expected", never "is present".

### I-0 Scope, method and evidence rules

#### I-0.1 In-scope namespaces (only these four are inventoried)

| Environment | Component | Namespace | Namespace rule (source) |
|---|---|---|---|
| Primary | Suite/Core | `mas-cot-core` | gitops `root-applications/ibm-mas-instance-root/templates/130-ibm-mas-suite-app.yaml:4` (`mas-%s-core`) |
| Primary | Manage | `mas-cot-manage` | saas-tekton `.tekton/gitops-suite-app-install.yaml:138` and `gitops-suite-app-config.yaml:167` (`MAS_APP_NAMESPACE=mas-${MAS_INSTANCE_ID}-${MAS_APP_ID}`); cli `image/cli/mascli/templates/gitops/appset-configs/cluster/instance/ibm-mas-masapp-install.yaml.j2:9` |
| Standby | Suite/Core | `mas-cot-sby-core` | same rule; implies instance ID `cot-sby` (**inferred**) |
| Standby | Manage | `mas-cot-sby-manage` | same rule; implies instance ID `cot-sby` (**inferred**) |

Placeholders: `<I>` = MAS instance ID (`cot` primary, `cot-sby` standby; both inferred from the namespace pattern), `<W>` = workspace ID (COT value **UNRESOLVED**; `main` only in the POC), `<mas_config_name>` = Helm value built by the CLI as `<I>-<type>-<scope>[-<ws>][-<app>]` (cli `image/cli/mascli/functions/gitops_mas_config:622-628`).

Resources outside these namespaces (cert-manager, `openshift-marketplace`, `mas-<I>-syncres`, AWS Secrets Manager, cluster-scoped objects) appear only in I-9 as external dependencies. Database backup/recovery is out of scope.

#### I-0.2 Evidence found, and what is missing

| Search | Result |
|---|---|
| `mas-cot*`, `cot`, `sby`, `standby` (non-Db2) in gitops, saas-envs, saas-deploy-py, cli, saas-tekton (and gitops-envs); working trees, all git history and branch names | **No match.** No COT or standby environment configuration exists locally. |
| Jira MASCORE-20742 | Not retrievable with the available Jira access; the "COT resource tree" referenced by the task is not available in any local source. |
| Live COT / standby cluster | Not accessed. |

Consequences: (a) COT/standby instance IDs, workspace ID, channels, enabled config charts, AWS SM paths and which Secrets/ConfigMaps actually exist are **UNRESOLVED**; (b) no "backed up" status can be asserted for COT; (c) `inst03` data is used only as a *pattern example*.

#### I-0.3 Evidence classes

| Class | Meaning | What it can prove |
|---|---|---|
| **Source (S)** | Helm template, root ApplicationSet template, CLI script, Tekton task, POC tool — cited as `repo path:line` | The resource *can* be generated / is *declared* in a tool list |
| **POC environment (P)** | `gitops-envs/fyre-noble8-dev/noble8/inst03` values and the local, gitignored POC backup `poc/suite-resource-dr/backups/inst03-20261023-174100/` | What existed in the **inst03 POC cluster only**. Not proof that the resource exists in COT |
| **Live COT (L)** | Output of `oc get` against COT/standby | **None collected** |

Evidence levels used in the tables: **VERIFIED** = the resource definition, name rule and namespace are shown by source (S); **PROBABLE** = the name or creator is inferred from source plus POC (P), or the template is conditional on values not available for COT; **UNRESOLVED** = no source, or the existing report's claim could not be reproduced.

**Backup status column.** Only `Not verified` appears, with the tool that *declares* the resource if any. "Declared in a tool list" is not "captured": no COT backup manifest exists, and the local inst03 backup has no `MANIFEST.json`. No resource is marked "backed up".

#### I-0.4 Source-of-truth chain

```text
gitops-envs / saas-envs values (per cluster, per instance)         [no COT file located]
  -> gitops root-applications/ibm-mas-instance-root/templates/*     (ArgoCD Applications, namespaces, sync waves)
  -> gitops instance-applications/*                                  (Helm templates: Subscription, CRs, config Secrets)
  -> AVP <path:arn:aws:secretsmanager:<region>:<acct>:secret:...>    (secret values; external source)
  -> operators (Suite core, Manage) + OLM + cert-manager             (generated Secrets/ConfigMaps/PVCs/certs)
saas-tekton / saas-deploy-py: pass inputs (MAS_APP_NAMESPACE, mas_app_global_secrets_yaml_manage) and schemas only; no DR resources.
cli: generates GitOps values (gitops_mas_config) and ships backup scripts and Tekton DR tasks.
```

### I-1–I-7 Inventory by category — Suite and Manage (Primary only)

**Scope of this part.** Only Suite (`mas-cot-core`) and Manage (`mas-cot-manage`) are enumerated. Standby (`mas-cot-sby-core`, `mas-cot-sby-manage`) is not repeated here; see the Standby note after I-7. Everything is **source-defined**: no entry is confirmed to exist in a live COT cluster (I-0.2), and no entry is confirmed backed up.

**Shared notes (apply to every entry, not repeated below).**

- **N1 Evidence.** VERIFIED = the definition, name rule and namespace are shown by the cited source line. PROBABLE = name or creator is inferred from source plus `inst03` POC data, or enablement in COT depends on values that are not available. UNRESOLVED = no source or not reproducible. **COT live presence is UNRESOLVED for every entry.**
- **N2 Gates.** `A` = chart renders only if `.Values.application_admin_role`; `C` = only if `.Values.cluster_admin_role`. The COT values for both are unknown. An entry with an extra condition states it.
- **N3 Names.** `<I>` = instance ID (`cot`, inferred from the namespace); `<W>` = workspace ID (COT value UNRESOLVED). `<mas_config_name>` is a Helm value; the CLI builds it as `<I>-<type>-<scope>[-<ws>][-<app>]` (cli `image/cli/mascli/functions/gitops_mas_config:622-628`).
- **N4 Backup (declared).** "CLI-core" = cli `image/cli/mascli/backup-restore/mascore-backup-restore.sh`; "CLI-manage" = `.../manage-backup-restore.sh`; "POC" = gitops `poc/suite-resource-dr/backup-suite-manage.sh` allowlist (L147-203). "Declared" means the script contains the command; it is **not** evidence that a backup ran or succeeded for COT. POC defaults are `INSTANCE=inst03`, `WORKSPACE_ID=main` (L25-26), so a COT run needs overrides (untested). The POC restore tool never applies Subscriptions, OperatorGroups, CSVs or CatalogSources (`restore.py:8-10`, `:101`). Tekton `suite-backup`/`suite-app-backup` tasks delegate to Ansible roles outside these repos, so their coverage is **not verified**.
- **N5 `inst03` data.** Names marked "POC" were seen in the `inst03` POC environment (`gitops-envs/fyre-noble8-dev/noble8/inst03/`, local backup `backups/inst03-20261023-174100/`). They show operator naming and ownership only; they are not proof for COT.
- **N6 Path aliases.** `SUITE` = gitops `instance-applications/130-ibm-mas-suite/templates/`; `INST` = gitops `instance-applications/500-540-ibm-mas-suite-app-install/templates/`; `CONF` = gitops `instance-applications/510-550-ibm-mas-suite-app-config/templates/`; `CFG` = gitops `instance-applications/<chart>/templates/`; `ROOT` = gitops `root-applications/ibm-mas-instance-root/templates/`.

### I-1 Secrets

#### Suite — `mas-cot-core`

1. **`Secret` `ibm-entitlement`** — `mas-cot-core`
   - Source: `SUITE/03-ibm-entitlement_Secret.yaml:1` (gate A), `:6` name, `:9` sync-wave 133. Value reference (POC env): gitops-envs `.../inst03/ibm-mas-suite.yaml:5` (AWS SM via AVP).
   - Backup (declared): CLI-core `:167`. POC: not listed.
   - Recovery: GitOps recreation; data from AWS Secrets Manager (external source).
   - Evidence: **VERIFIED** (definition). COT AWS SM path UNRESOLVED.
2. **`Secret` `cot-credentials-superuser`** — `mas-cot-core` — **state-bearing**
   - Source: no creator template in any repo. Consumers: `CONF/04-postsync-manage-sanity.yaml:573`, `600-ibm-post-sync-jobs/templates/001-ibm-create-initial-users.yaml:125` (comment), cli `python/src/mas/cli/must_gather/common/coreapi.py:48`. State hint: `poc/suite-resource-dr/dr_lib.py:52`.
   - Backup (declared): CLI-core `:168`; POC `:164` (optional).
   - Recovery: restore from backup. Operator is the presumed creator (inferred); regeneration is not evidenced, so do not assume it is safe.
   - Evidence: **PROBABLE** (name verified, creator inferred). Absent from the `inst03` POC backup directory, so even the POC does not prove it exists. **Unresolved risk R2.**
3. **`Secret` `cot-keys-jwt`** — `mas-cot-core` — state-bearing candidate
   - Source: POC `:162`; POC backup `core/secrets-inst03-keys-jwt.yaml` (owner Suite). No GitOps source. Hint `dr_lib.py:52`.
   - Backup (declared): POC only; not in CLI-core.
   - Recovery: restore if preserved; otherwise operator reconciliation (effect of regeneration on issued tokens is inferred, not tested).
   - Evidence: **PROBABLE**.
4. **`Secret` `cot-cert-public`** — `mas-cot-core` — conditional
   - Source: `SUITE/01-ibm-mas_suite_cert_Secret.yaml:1-2` (gate A **and** `mas_manual_cert_mgmt`), `:7` name.
   - Backup (declared): CLI-core `:58-59`, only when `Suite.spec.settings.manualCertMgmt` is true.
   - Recovery: external source (customer certificate) / GitOps recreation.
   - Evidence: **VERIFIED** (definition); applicability UNRESOLVED (`inst03` sets it false: `.../ibm-mas-suite.yaml:17`).
5. **Config-credential Secrets** (rendered only for the config charts COT enables) — `mas-cot-core`
   - Source (all gate A plus the stated extra condition): `<mas_config_name>-credentials` for JdbcCfg `CFG:130-ibm-jdbc-config/01-suite_jdbccfg.yaml:1,7`; SlsCfg `130-ibm-mas-sls-config/04-sls-registration_Secret.yaml:1,7`; BasCfg `130-ibm-mas-bas-config/01-dro-api-token_Secret.yaml:1,6`; IDPCfg `130-ibm-mas-idp-config/01-ldap-credentials_Secret.yaml:1,6`; SmtpCfg `130-ibm-mas-smtp-config/01-smtp-credentials_Secret.yaml:1,6`; AiCfg `130-ibm-mas-aicfg-config/01-suite_aicfg.yaml:1,7` (extra: `aiservice_enabled`). Name from a value: Mongo `130-ibm-mas-mongo-config/01-mongo-credentials_Secret.yaml:6` (`config.credentials.secretName`); Kafka `130-ibm-kafka-config/01-kafka-credentials_Secret.yaml:1,6` (extra: `suite_kafka_username`); ObjectStorage `130-ibm-objectstorage-config/01-objectstorage-credentials_Secret.yaml:1,6` (extra: `suite_objectstorage_username`). Fixed name: `cot-usersupplied-watsonstudio-creds-system` `130-ibm-watson-studio-config/01-watson-studio-credentials_Secret.yaml:6`.
   - Backup (declared): CLI-core backs up the Secret named in `spec.config.credentials.secretName` of each CR it lists (`:38-42`): mongo, kafka, jdbc, sls, bas, smtp, watsonstudio, objectstorage, idp. No declaration for AiCfg. POC: none.
   - Recovery: GitOps recreation with values from AWS SM (external). Not state-bearing by source; whether the AWS SM entries still exist is outside these repos.
   - Evidence: **PROBABLE** (definitions verified; COT enablement and exact names UNRESOLVED).
6. **`Secret` `pre-jreporter-<reporter_name>-devopsuri`** — `mas-cot-core` — CI only
   - Source: gitops `sub-charts/junitreporter/templates/00-presync-report-starter.yaml:14`; rendered only if `junitreporter.devops_mongo_uri != ""` (`130-ibm-mas-suite/Chart.yaml:8-11`).
   - Backup: not declared. Recovery: none required (ephemeral PreSync hook object).
   - Evidence: **PROBABLE**.

#### Manage — `mas-cot-manage`

1. **`Secret` `ibm-entitlement`** — `mas-cot-manage`
   - Source: `INST/02-ibm-entitlement_Secret.yaml:1` (gate A), `:6`, `:9` wave 501. Value reference (POC env): gitops-envs `.../inst03/ibm-mas-masapp-manage-install.yaml:4`.
   - Backup (declared): CLI-manage `:160`. POC: not listed.
   - Recovery: GitOps recreation; AWS SM (external).
   - Evidence: **VERIFIED** (definition).
2. **`Secret` Manage encryption Secret — name = `.Values.mas_appws_spec.settings.db.encryptionSecret`** — `mas-cot-manage` — **state-bearing, naming conflict**
   - Source: `CONF/01-ibm-manage_encryption_secret.yaml:1-17`; name `:16`, namespace `:17`, data from `global_secrets` `:19-20`. Gates: A (`:1`), `mas_app_id` is manage or health (`:2`), `global_secrets` present (`:3`), `encryptionSecret` key present (`:4`). `global_secrets` is forwarded by `ROOT/510-550-ibm-mas-masapp-configs.yaml:123-124` and by saas-tekton `.tekton/mas-apps-listener.yaml:403,466`. Hint: `dr_lib.py:52`. POC value: `main-manage-encryption-secret` (gitops-envs `.../inst03/ibm-mas-masapp-configs.yaml:24`).
   - Backup (declared): CLI-manage `:161` uses the literal `<W>-manage-encryptionsecret` (no hyphen between "encryption" and "secret"). POC `:180` uses `<W>-manage-encryption-secret` (marked required). The names differ. The CLI's generic scan of `secretName` keys in `ManageWorkspace` (`:36-50`) does not help: in the `inst03` ManageWorkspace copy only three `secretName` keys occur (`cos-logging`, two add-server-config Secrets) and `encryptionSecret` is a different key. That is POC data, not COT.
   - Recovery: restore from backup (state-bearing; holds `MXE_SECURITY_CRYPTO*` keys, so loss is assumed to make encrypted Manage data unreadable). It can be regenerated from GitOps only if COT supplies `global_secrets`. `inst03` does not, so there it is operator-created.
   - Evidence: **UNRESOLVED** (COT name, creator and backup). **Unresolved risk R1.**
3. **`Secret` `<W>-manage-encryption-secret-operator`** (POC name `main-manage-encryption-secret-operator`) — `mas-cot-manage` — state-bearing
   - Source: no GitOps source. POC `:181`; CLI-manage `:162` declares `<W>-manage-encryptionsecret-operator` (same naming mismatch). Owner ManageWorkspace in the POC backup.
   - Recovery: restore from backup (paired with entry 2).
   - Evidence: **PROBABLE**. **Risk R1.**
4. **`Secret` `cot-keys-ltpa`** — `mas-cot-manage` — continuity candidate
   - Source: POC `:189`; hint `dr_lib.py:52`; no GitOps source; no owner in the POC backup.
   - Backup (declared): POC only; not in CLI-manage.
   - Recovery: restore for SSO continuity, or operator reconciliation (impact of regeneration inferred).
   - Evidence: **PROBABLE**.
5. **`Secret` add-server-config Secrets** (names are the keys of `mas_app_server_bundles_combined_add_server_config`) — `mas-cot-manage`
   - Source: `CONF/01-ibm-manage_additional_server_config_secrets.yaml:1-3` (gate A, manage or health, one Secret per key), `:11` name, `:12` namespace.
   - Backup (declared): CLI-manage `:36-50` backs up Secrets referenced by `secretName` in `ManageWorkspace`. POC `:182-183` lists only the `inst03` names `main-manage-d--sb0--asc--sn` and `...sb1...`.
   - Recovery: GitOps recreation; XML content from AWS SM (external).
   - Evidence: **PROBABLE** (names are value-driven; COT use UNRESOLVED).
6. **`Secret` `.Values.manage_logging_secret_name`** (`cos-logging` in POC) — `mas-cot-manage` — conditional on that value
   - Source: `CONF/01-ibm-manage_logging_secrets.yaml:1-3,15,16`.
   - Backup (declared): CLI-manage generic `secretName` scan; POC `:184` (`cos-logging` literal).
   - Recovery: GitOps recreation; AWS SM (external).
   - Evidence: **PROBABLE**.
7. **`Secret` customization-archive Secrets** (`customization_archive_secret_names[].secret_name`) — conditional
   - Source: `CONF/01-ibm-manage_customization_archive_secrets.yaml:1-3,15,16`.
   - Backup: not declared by name. Recovery: GitOps recreation; external source.
   - Evidence: **PROBABLE** (COT use UNRESOLVED).
8. **`Secret` `.Values.public_tls_secret_name`** — conditional (manual certificates)
   - Source: `INST/02-ibm-mas_suite_cert_Secret.yaml:1-3,8` (gate A, `mas_manual_cert_mgmt`, name value set; wave 501 `:11`); `CONF/01-ibm-mas_suite_cert_Secret.yaml:1-3,8`.
   - Backup (declared): CLI-manage `:62-73` backs up `<I>-<W>-cert-public-81` only if `Suite.spec.settings.manualCertMgmt` is true. Whether that equals `public_tls_secret_name` is not shown.
   - Recovery: external source (customer certificate) / GitOps recreation.
   - Evidence: **PROBABLE**; applicability UNRESOLVED.
9. **Operator-generated Secrets** (POC names; no GitOps source): `cot-suite-system-binding`, `cot-coreidp-system-binding`, `cot-<W>-jdbccfg-workspace-application-binding`, `cot-credentials-oauth-manage`, `cot-<W>-truststore`, `cot-<W>-manage-truststorepasswd`, `cot-<W>-internal-maximoproperty-secret`, `<W>-{default,foundation}-{bundleproperty,nonsystemproperty}`, `<W>-jmsserver-bundleproperty`, `<W>-smtp-oauth-properties` — `mas-cot-manage`
   - Source: POC `:185-186,191-195,197-202`; owners (ManageApp, ManageWorkspace, Truststore, ManageServerBundle, ManageDeployment) from the POC backup. `suite-system-binding` is also named in `INST/05-ibm-mas_essential_rbac.yaml:9` (comment).
   - Backup (declared): POC allowlist only; not in CLI-manage.
   - Recovery: operator reconciliation. Automatic recreation is assumed, not proven (`dr_lib.py:305`). Bundle names depend on the COT ManageWorkspace bundle list (UNRESOLVED).
   - Evidence: **PROBABLE**.
10. **Hook-test Secrets** `postsync-sanity-manage-devopsuri`, `postsync-verify-manage-devopsuri`, `pre-jreporter-<reporter_name>-devopsuri` — CI only
    - Source: `CONF/04-postsync-manage-sanity.yaml:17,58` (extra: `run_sanity_test`), `CONF/04-postsync-manage-verify.yaml:14,55`, junitreporter as in Suite entry 6.
    - Backup: not declared. Recovery: none required (ephemeral).
    - Evidence: **PROBABLE**.

### I-2 Custom Resources (CRs)

#### Suite — `mas-cot-core`

1. **`Suite` (core.mas.ibm.com/v1) `cot`**
   - Source: `SUITE/04-ibm-mas_Suite.yaml:1` (gate A), `:4` kind, `:20` name, `:21` namespace, `:7` wave 139. Spec fields: `certManagerNamespace` `:24` (default `cert-manager`), `manualCertMgmt` `:47`, `internalCertificateAuthority` `:70` (conditional). ArgoCD app `suite.<cluster>.<I>`: `ROOT/130-ibm-mas-suite-app.yaml:3-4` (exists only if `ibm_mas_suite` is non-empty, `:1`).
   - Backup (declared): CLI-core `:170`; POC `:148` (required).
   - Recovery: GitOps recreation. State Secrets (I-1 Suite 2, 3) must be restored first.
   - Evidence: **VERIFIED** (definition and namespace rule). Instance ID `cot` is inferred.
2. **`Workspace` (core.mas.ibm.com/v1) `cot-<W>`**
   - Source: `CFG:220-ibm-mas-workspace/01-ibm-mas_WorkspaceCfg.yaml:1,4,6,7`. ArgoCD app: `ROOT/200-ibm-mas-workspaces.yaml:8-9` (range over `ibm_mas_workspaces`, gate A).
   - Backup (declared): CLI-core `:176` (`workspaces`). POC: none.
   - Recovery: GitOps recreation.
   - Evidence: **VERIFIED** (definition); `<W>` UNRESOLVED.
3. **Suite config CRs (config.mas.ibm.com/v1), name `<mas_config_name>`** — only those COT enables. ArgoCD app: `ROOT/130-ibm-mas-suite-configs-app.yaml:8-9` (range over `ibm_mas_suite_configs`, gate A).
   - Source (kind, line of `kind`/`name`; all also gate A, with extra where stated): `MongoCfg` `CFG:130-ibm-mas-mongo-config/02-ibm-mas_MongoCfg.yaml:4,6`; `KafkaCfg` `130-ibm-kafka-config/02-ibm-mas_KafkaCfg.yaml:1,4,6` (extra `kafka_config`); `JdbcCfg` `130-ibm-jdbc-config/01-suite_jdbccfg.yaml:20,22`; `SlsCfg` `130-ibm-mas-sls-config/05-ibm-mas_SlsCfg.yaml:4,6`; `BasCfg` `130-ibm-mas-bas-config/03-ibm-mas_BasCfg.yaml:4,6`; `SmtpCfg` `130-ibm-mas-smtp-config/02-ibm-mas_SmtpCfg.yaml:4,6`; `WatsonStudioCfg` `cot-watsonstudio-system` `130-ibm-watson-studio-config/02-ibm-mas_WatsonStudioCfg.yaml:4,6`; `ObjectStorageCfg` `130-ibm-objectstorage-config/02-ibm-mas_ObjectStorageCfg.yaml:1,4,6` (extra `objectstorage_config`); `IDPCfg` `130-ibm-mas-idp-config/02-ibm-mas_IdpCfg.yaml:4,6`; `AiCfg` `130-ibm-mas-aicfg-config/01-suite_aicfg.yaml:28,30` (extra `aiservice_enabled`); `AppCfg` `130-ibm-mas-app-config/01-appcfg.yaml:4,6`.
   - Backup (declared): CLI-core `:171` mongocfgs, `:172` kafkacfgs, `:173` jdbccfgs, `:174` slscfgs, `:175` bascfgs, `:177` smtpcfgs, `:178` watsonstudiocfgs, `:179` objectstoragecfgs, `:182` idpcfgs. **No declaration** for AiCfg or AppCfg. POC: none.
   - Recovery: GitOps recreation (credentials per I-1 Suite 5).
   - Evidence: **PROBABLE** (definitions verified; COT enablement and exact names UNRESOLVED). POC names for reference only: `inst03-mongo-system`, `inst03-jdbc-wsapp-main-manage`, `inst03-sls-system`, `inst03-bas-system` (`.../inst03/ibm-mas-suite-configs.yaml`).
4. **`GenericAddon` (addons.mas.ibm.com/v1), namespace `mas-cot-core`** — each is conditional; ArgoCD app `ROOT/550-ibm-mas-addons-config.yaml:3` (gate A and at least one addon value)
   - Source (`CFG:550-ibm-mas-addons-config/` file: name line; condition): `01-allowlist-cr.yaml:7` `cot-addons-allowlist` (`allow_list` non-empty); `02-additional-vpn-cr.yaml:7` `cot-addons-additionalvpn` (`additional_vpn`); `03-enhanced-dr-cr.yaml:7` `cot-addons-enhanceddr` (`enhanced_dr`); `04-extensions-cr.yaml:7` `cot-addons-extensions` (`extensions`); `05-replica-db-cr.yaml:7` `cot-addons-replica-db` (`databases` non-empty); `06-nonshared-cluster-cr.yaml:8` `cot-addons-nonsharedcluster` (`cluster_nonshared` true and `operational_mode` not `nonproduction`); `07-application-configuration-cr.yaml:7` `cot-addons-saas-maf-enablement` (`application_configuration`); `08-additional-resources-cr.yaml:7` `cot-addons-additional-resources` (`additional_resources`); `09-production_db_access-cr.yaml:7` `cot-addons-production-database-access` (`production_database_access`).
   - Backup: not declared by CLI-core or POC. Recovery: GitOps recreation.
   - Evidence: **PROBABLE** (which addons COT enables is UNRESOLVED; `enhanced_dr` semantics not inspected).
5. **Operator-managed Suite CRs without GitOps source** (`ScimCfg`, `CoreIDP`, `PushNotificationCfg`, `AppConnect`, `Humai`, `MviEdge`)
   - Source: no template. Names appear in operator RBAC tables (cli `docs/catalogs/packages/ibm-mas/9.2.8.md:100,104`). CLI-core declares `pushnotificationcfgs :180`, `scimcfgs :181`, `appconnects :183`, `humai :184`, `mviedges :185`.
   - Recovery: operator reconciliation (unproven) or restore if the CLI backup captured them.
   - Evidence: **UNRESOLVED** (instances and names unknown).

#### Manage — `mas-cot-manage`

1. **`ManageApp` (apps.mas.ibm.com/v1) `cot`** (kind from `mas_app_kind`; `inst03`: `ManageApp`)
   - Source: `INST/05-ibm-mas_Suite_App_Install.yaml:1` (gate A), `:4` kind, `:12` name, `:13` namespace, `:7` wave 503; `helm.sh/resource-policy: keep` when `use_postdelete_hooks` (`:9-11`). ArgoCD app `manage.<cluster>.<I>`: `ROOT/500-ibm-mas-masapp-manage-install.yaml:1,7`; namespace created with `CreateNamespace=true` when C (`:100-101`).
   - Backup (declared): CLI-manage `:163`. POC: none.
   - Recovery: GitOps recreation.
   - Evidence: **VERIFIED** (definition).
2. **`ManageWorkspace` (apps.mas.ibm.com/v1) `cot-<W>`**
   - Source: `CONF/02-ibm-mas_Suite_App_workspace.yaml:1` (gate A), `:4` kind (`mas_app_ws_kind`), `:12` name, `:13` namespace, `:7` wave 605; keep policy `:9-11`. ArgoCD app: `ROOT/510-550-ibm-mas-masapp-configs.yaml`.
   - Backup (declared): CLI-manage `:164` (all ManageWorkspace plus Secrets named under `secretName`); POC `:149` (required).
   - Recovery: GitOps recreation, after the encryption Secrets (I-1 Manage 2, 3) are in place.
   - Evidence: **VERIFIED** (definition); `<W>` UNRESOLVED.
3. **Core `JdbcCfg` used by Manage** (lives in `mas-cot-core`; see I-2 Suite 3)
   - Backup (declared): CLI-manage `:165` backs up `jdbccfgs` from the core namespace.
   - Evidence: **PROBABLE**.
4. **Operator-created Manage CRs** `Truststore` (truststore-mgr.ibm.com/v1) `cot-<W>-truststore`, `ManageServerBundle` (`default`, `foundation`, `jmsserver`), `ManageDeployment` `manage-maxinst`
   - Source: no GitOps source; seen only as `ownerReferences` in the POC backup `manage/*.yaml`.
   - Backup: not declared. Recovery: operator reconciliation.
   - Evidence: **PROBABLE** (POC only).

### I-3 Subscriptions

#### Suite — `mas-cot-core`

1. **`Subscription` (operators.coreos.com/v1alpha1) `ibm-mas-operator`**
   - Source: `SUITE/02-ibm-mas_Subscription.yaml:1` (gate C), `:6` name, `:7` namespace, `:9` wave 133, `:16` channel (`mas_channel`), `:17` plan (default Automatic), `:18` package `ibm-mas`, `:19` source `ibm-operator-catalog`, `:20` `openshift-marketplace`.
   - Backup (declared): CLI-core `:166`. POC restore never applies Subscriptions.
   - Recovery: GitOps recreation, then OLM installation (needs the CatalogSource, I-9).
   - Evidence: **VERIFIED** (definition). COT channel UNRESOLVED (`inst03`: `9.2.x-dev`).
2. **`Subscription` `ibm-truststore-mgr`** — listed by the existing POC report, no source
   - Source: none in gitops; cli `python/src/mas/cli/mirror/config.py:16` is a mirror package list, not a Subscription.
   - Evidence: **UNRESOLVED**.

#### Manage — `mas-cot-manage`

1. **`Subscription` `ibm-mas-manage`** (metadata name `ibm-mas-<mas_app_id>`)
   - Source: `INST/04-ibm-mas_Subscription.yaml:1` (gate C), `:6` name, `:7` namespace, `:9` wave 502, `:16` channel (`mas_app_channel`), `:17` plan, `:18-22` package (`ibm-mas-manage`), `:23` source (`mas_app_catalog_source`), `:24` `openshift-marketplace`.
   - Backup (declared): CLI-manage `:155`. The existing report's name `ibm-mas-manage-operator` does not match.
   - Recovery: GitOps recreation, then OLM installation.
   - Evidence: **VERIFIED** (definition). COT channel UNRESOLVED.
2. **`Subscription` `ibm-truststore-mgr`** — **UNRESOLVED**, same reason. A `Truststore` CR exists in the POC backup, but the providing Subscription is not evidenced.

### I-4 OLM resources

#### Suite — `mas-cot-core`

1. **`OperatorGroup` `ibm-mas-operator-group`**
   - Source: `SUITE/01-ibm-mas_OperatorGroup.yaml:1` (gate C), `:6` name, `:7` namespace, `:9` wave 131. The existing report's name `mas-inst03-core-operatorgroup` does not match.
   - Backup (declared): CLI-core `:169`. POC restore never applies OperatorGroups.
   - Recovery: GitOps recreation.
   - Evidence: **VERIFIED** (definition).
2. **`ClusterServiceVersion` `ibm-mas.v<version>`, `InstallPlan`** — created by OLM from the Subscription (general OLM behaviour; no repo file defines them)
   - Backup: not declared; by design not restored. Recovery: OLM installation.
   - Evidence: **UNRESOLVED** (exact names and versions unknown).

#### Manage — `mas-cot-manage`

1. **`OperatorGroup` `mas-cot-manage-operator-group`** (`<mas_app_namespace>-operator-group`)
   - Source: `INST/03-ibm-mas_OperatorGroup.yaml:1` (gate C), `:6` name, `:7` namespace, `:9` wave 501, `:17` target namespace. The existing report's name `mas-inst03-manage-operatorgroup` does not match.
   - Backup (declared): CLI-manage `:156-159` (name auto-discovered via `oc get operatorgroup`).
   - Recovery: GitOps recreation.
   - Evidence: **VERIFIED** (definition).
2. **`ClusterServiceVersion` `ibm-mas-manage.v<version>`, `InstallPlan`** — OLM-generated; **UNRESOLVED** as for Suite entry 2.

*CatalogSource `ibm-operator-catalog` is in `openshift-marketplace` (outside both namespaces): reference only, see I-9.*

### I-5 ConfigMaps

#### Suite — `mas-cot-core`

1. **Operator-created ConfigMaps** `cot-catalog-items`, `cot-catalog-settings`, `cot-nps`, `cot-settings-applications`, `cot-suite-reconcile`, `cot-supported-applications`
   - Source: no GitOps source. POC `:156-161`; owner Suite in the POC backup `core/configmaps-*.yaml`.
   - Backup (declared): POC only; not in CLI-core.
   - Recovery: operator reconciliation.
   - Evidence: **PROBABLE** (POC data only).
2. **`ConfigMap` `set-welcome-message-state`** — conditional
   - Source: name derived at `SUITE/07-postsync-set_welcome_messsage_Job.yaml:7,68` (`<prefix>-state`); created by the Job in the core namespace (`:204-205`, `:290-293`). Gate A and `welcome_message` (`:1-2`).
   - Backup: not declared. Recovery: re-created by the Job; holds the last-applied welcome message only (`:241`).
   - Evidence: **VERIFIED** (name rule); COT use UNRESOLVED.
3. **`ConfigMap` `pre-jreporter-<reporter_name>-synctime`** — CI only
   - Source: gitops `sub-charts/junitreporter/templates/00-presync-report-starter.yaml:9`; condition as in I-1 Suite 6.
   - Recovery: none required (ephemeral).
   - Evidence: **PROBABLE**.

#### Manage — `mas-cot-manage`

1. **`ConfigMap` `cot-manage-install-placeholder`**
   - Source: `INST/00-placeholder.yaml:1` (gate A), `:9` name, `:10` namespace. POC `:175`.
   - Backup (declared): POC only. Recovery: GitOps recreation (empty ArgoCD anchor, no data to preserve).
   - Evidence: **VERIFIED**.
2. **`ConfigMap` `cot-manage-<W>-config-placeholder`** (name `<I>-<app>-<W>-config-placeholder`)
   - Source: `CONF/00-placeholder.yaml:4,7,8`. POC `:176`.
   - Recovery: GitOps recreation (no data).
   - Evidence: **VERIFIED**; `<W>` UNRESOLVED.
3. **Operator-created ConfigMaps** (POC names): `cot-coreidp-binding-reconcile`, `cot-suite-binding-reconcile`, `cot-<W>-{aicfg,jdbccfg,optimizerworkspace,smtpcfg}-binding-reconcile`, `cot-<W>-{instance-monitor,server-monitor,truststore}-cfg`, `cot-<W>-truststore-tsmcfg`, `cot-<W>-supported-pod-keys`, `maximo-config`
   - Source: POC `:165-174,177-178`; owners from the POC backup. No GitOps source.
   - Backup (declared): POC only; not in CLI-manage.
   - Recovery: operator reconciliation.
   - Evidence: **PROBABLE**. The existing report's `<I>-main-manage-status` and `metering-sls-entitlement` were not found in any repo or in the POC backup (**UNRESOLVED**).
4. **Hook-test ConfigMaps** `postsync-sanity-tests-manage-cm`, `postsync-sanity-mcp-tests-manage-cm`, `postsync-sanity-tests-manage-record-cm`; `postsync-verify-tests-manage-cm`, `postsync-verify-tests-manage-record-cm`; `pre-jreporter-<reporter_name>-synctime` — conditional, CI only
   - Source: `CONF/04-postsync-manage-sanity.yaml:23-25,288,1450,1573` (extra: `run_sanity_test`); `CONF/04-postsync-manage-verify.yaml:20-21,204,481`; POC `:179` for the junitreporter map (POC name `pre-jreporter-app-install-manage-inst03-synctime`).
   - Recovery: none required (ephemeral).
   - Evidence: **PROBABLE**.

### I-6 Certificates

No `Certificate` or `Issuer` is defined for `mas-cot-core` or `mas-cot-manage` in gitops (search of `kind: Certificate|Issuer` across `instance-applications`, `cluster-applications`, `sub-charts` found only Db2, DRO, mongodb, provisioner, CIS webhook and CP4D objects in other namespaces). Absence in source is not proof of absence in COT.

#### Suite — `mas-cot-core`

1. **Suite certificate configuration** (drives cert-manager; no Certificate object in source)
   - Source: `SUITE/04-ibm-mas_Suite.yaml:24` (`certManagerNamespace`, default `cert-manager`), `:29-36` (`certificateIssuer` `<I>-<dns_provider>-le-stg|prod` when `dns_provider` is akamai or cis and not manual), `:47` `manualCertMgmt`.
   - Recovery: GitOps recreation of the `Suite` CR; the operator then requests certificates (inferred).
   - Evidence: **PROBABLE**.
2. **cert-manager-issued Secrets**: `cot-admindashboard-cert-internal`, `cot-internalapi-cert-internal`, `cot-coreapi-cert-internal`
   - Source: `admindashboard` POC `:163` (annotation `cert-manager.io/issuer-name: mas-inst03-core-internal-issuer`, POC backup `core/secrets-inst03-admindashboard-cert-internal.yaml`); `internalapi` referenced at `SUITE/07-postsync-set_welcome_messsage_Job.yaml:69,188`; `coreapi` named in a comment at `600-ibm-post-sync-jobs/templates/001-ibm-create-initial-users.yaml:127`. No creator template.
   - Backup (declared): POC `:163` for admindashboard only.
   - Recovery: cert-manager re-issuance, if the issuers and CA Secret (outside scope, I-9) exist.
   - Evidence: **PROBABLE**.
3. **ClusterIssuers `cot-cis-le-prod` / `cot-cis-le-stg`** — cluster-scoped, reference only
   - Source: `SUITE/00-8-ibm-cis_clusterissuer-prod.yml:1,11` and `-staging.yml:1,12`; gate C, `dns_provider` is `cis`, not manual certs, matching `environment_type`.
   - Evidence: **VERIFIED** (definition); applicability UNRESOLVED.

#### Manage — `mas-cot-manage`

1. **cert-manager-issued Secrets** (POC names): `cot-internal-manage-tls`, `cot-internal-mobile-encryption`, `cot-workspaceagent-tls`, `cot-<W>-cert-public-81`
   - Source: POC `:187,188,196,190`; cert-manager annotations in the POC backup `manage/secrets-inst03-*.yaml` (issuers `mas-inst03-core-{internal,public}-issuer`). `internal-manage-tls` is also referenced by `600-ibm-post-sync-jobs/templates/001-ibm-create-initial-users.yaml:129,188`. No creator template.
   - Backup (declared): POC only; CLI-manage `:71` declares `cert-public-81` for manual certificates only.
   - Recovery: cert-manager re-issuance via the operator (inferred).
   - Evidence: **PROBABLE**.
2. **Manual-certificate Secret** — see I-1 Manage 8.

*CA Certificates, Issuers, CA Secret and ClusterIssuers `mas-cot-core-{internal,public}-issuer` (pattern from POC `:150-155`) live outside both namespaces: reference only, see I-9. CA key continuity is an open decision in the existing report.*

### I-7 RBAC and other relevant resources

#### I-7a RBAC — Suite (`mas-cot-core`)

1. **`Role` `mas-application-admin`, `RoleBinding` `mas-application-admin-binding`**
   - Source: `600-application-admin-rbac/templates/per-namespace-rbac.yaml:33,271` (generated file, do not edit); namespace included when `ibm_mas_suite_deployed` (`:10`); ArgoCD app `ROOT/600-application-admin-rbac-app.yaml:1` (gate C).
   - Backup: not declared. Recovery: GitOps recreation.
   - Evidence: **VERIFIED** (definition); applicability UNRESOLVED.
2. **Hook-support objects rendered by the Suite chart** (all gate A):
   - `postdelete-delete-cr-{np,r,sa,rb}` — NetworkPolicy/Role/ServiceAccount/RoleBinding, `SUITE/01-postdelete-crs-resources.yaml:15-18` (kinds `:25,46,100,113`).
   - `mas-route-np`, `mas-route-sa`, `mas-route-prereq-role-<I>`, `mas-route-prereq-rb-<I>` and a `mas-route-patch-<hash>` Job, `SUITE/05-postsync-add-label_Job.yaml:61,69,91,105,135`.
   - `postsync-configtool-oidc-{np,r,sa,rb}` and Job, `SUITE/06-postsync-configtool-oidc.yaml:63-66`; extra condition: channel is a 9.0.x or 8.x series (`:3`).
   - `set-welcome-message-{np,r,sa,rb-core}` and Job, `SUITE/07-postsync-set_welcome_messsage_Job.yaml:62-65`; extra: `welcome_message`.
   - `predelete-wait-configs-{np,sa}` and a Job, `SUITE/08-predelete-wait-for-configs_Job.yaml:33-36` (PreDelete hooks `:50,72,86`); it also renders a cluster-scoped `ClusterRole`/`ClusterRoleBinding` (`:81,108`, reference only).
   - Backup: not declared. Recovery: GitOps recreation; hook Jobs re-run on sync.
   - Evidence: **VERIFIED** (definitions); COT gates UNRESOLVED.

#### I-7a RBAC — Manage (`mas-cot-manage`)

1. **`Role`/`RoleBinding` `mas:cot:core:internalapi:manage:essential` and `mas:cot:core:coreapi:manage:essential`**
   - Source: `INST/05-ibm-mas_essential_rbac.yaml`: Role `:25`, RoleBinding `:50` (subject `ibm-mas-internalapi` `:61`), Role `:69`, RoleBinding `:88` (subject `ibm-mas-coreapi` `:99`). Condition: `instance_id` set and `mas_app_id` is manage (`:18`). The file header (`:2-16`) says the Manage operator also creates them.
   - Backup: not declared. Recovery: GitOps recreation (operator also reconciles them).
   - Evidence: **VERIFIED** (definition).
2. **`Role` `mas-application-admin`, `RoleBinding` `mas-application-admin-binding`**
   - Source: `per-namespace-rbac.yaml:33,271`; namespace included when `ibm_suite_app_manage_deployed` (`:13`).
   - Recovery: GitOps recreation.
   - Evidence: **VERIFIED** (definition).
3. **Hook-support objects rendered by the Manage charts**:
   - `postdelete-delete-appws-cr-{r,rb}` Role/RoleBinding in the app namespace, `INST/08-postdelete-appns-rbac.yaml:7-8,12,63` (extra: `use_postdelete_hooks`); SA `postdelete-delete-cr-sa` and Jobs `INST/07-postdelete-delete-app-cr.yaml:28-30`, `CONF/03-postdelete-delete-appws-cr.yaml:19,24-26`.
   - `mas-app-route-{np,sa}`, `mas-app-route-prereq-{role,rb}-<I>-<app>` and a patch Job, `CONF/04-postsync-add-label_Job.yaml:9,17,41,57,104`.
   - `postsync-sanity-manage-*` (np, role, core-role, rb, core-rb, `sa-<I>`, Job), `CONF/04-postsync-manage-sanity.yaml:16-26` (extra: `run_sanity_test`); `postsync-verify-manage-*` including a cluster-scoped `ClusterRole`/`ClusterRoleBinding` (reference only), `CONF/04-postsync-manage-verify.yaml:13-22`.
   - `<W>-manage-update-{np,role,sa,rb}`, `CONF/02-ibm-manage-update_Job.yaml:5-16` (extra: `db.upgrade.upgradeType == onlineUpgrade`).
   - DB-related hooks, **out of scope**: `postsync-manage-db2-*` (`CONF/700-702-postsync-db2-manage.yaml:9-10`, extra `manage_db2u_databases`), `postsync-app-rds-roles-*` (`CONF/703-postsync-rds-app-roles.yaml:9-10`, extra `mas_rds_databases`).
   - Backup: not declared. Recovery: GitOps recreation; hooks re-run on sync.
   - Evidence: **VERIFIED** (definitions); COT gates UNRESOLVED.

#### I-7b Other relevant resources

**Suite — `mas-cot-core`**

1. **`Namespace` `mas-cot-core`** — cluster-scoped reference. Source: `ROOT/130-ibm-mas-suite-app.yaml:4` (name rule), `:174-175` (`CreateNamespace=true` when C); `ROOT/130-ibm-mas-suite-configs-app.yaml:88`. Recovery: GitOps recreation. Evidence: **VERIFIED**.
2. **Operator-reconciled workloads** (Deployments, Services, Routes, PVCs, etc.). Source: none enumerable offline. Recovery: operator reconciliation. Evidence: **UNRESOLVED**; requires live discovery (`discover.py:191-240`).

**Manage — `mas-cot-manage`**

1. **`Namespace` `mas-cot-manage`** — cluster-scoped reference. Source: `ROOT/500-ibm-mas-masapp-manage-install.yaml:100-101` (`CreateNamespace=true` when C); `ROOT/510-550-ibm-mas-masapp-configs.yaml:244` (`CreateNamespace=false`). Recovery: GitOps recreation. Evidence: **VERIFIED**.
2. **`PersistentVolumeClaim` `mas-<I>-jmsserver-pvc`** (POC spec: 25Gi, RWX, `nfs-client`)
   - Source: gitops-envs `.../inst03/ibm-mas-masapp-configs.yaml:43-49` (`pvcName` at `:47`), part of the ManageWorkspace spec. COT value unknown.
   - Backup (declared): none; no inspected tool backs up PV contents.
   - Recovery: operator creates the PVC from the spec (inferred); queue data is not recovered.
   - Evidence: **PROBABLE**. Whether the data matters is undecided (**R4**).
3. **Visual Inspection resources** (`ResourceQuota`, `StorageClass`, SCC Jobs, JVM ConfigMap): `INST/04-ibm-mas-mvi_ResourceQuota.yaml:2`, `INST/05-ibm-mas_custom_service_jvm_config_mvi.yaml:2` render only for `mas_app_id == visualinspection`, so they do not apply to Manage.
4. **Operator-reconciled workloads.** Source: none enumerable offline. Evidence: **UNRESOLVED**.

### Standby note

`mas-cot-sby-core` and `mas-cot-sby-manage` are not enumerated here. The same templates would apply with `<I>=cot-sby`, which is inferred from the namespace names only. Any name containing `<I>` would be at most PROBABLE, and presence, backup and workspace ID are UNRESOLVED. The POC tooling has no standby mode (I-11 item 4). The standby namespaces remain in the scope table I-0.1.

### Open recovery risks carried by this inventory

- **R1 Manage encryption Secret naming.** The Secret name comes from `.Values.mas_appws_spec.settings.db.encryptionSecret` (`CONF/01-ibm-manage_encryption_secret.yaml:1-17`). CLI-manage declares `<W>-manage-encryptionsecret[-operator]` (`:161-162`); the POC declares `<W>-manage-encryption-secret[-operator]` (`:180-181`). If COT uses the hyphenated name, the CLI declaration does not match it, and the `secretName` scan does not pick it up in the `inst03` shape. COT name, creator and backup are **UNRESOLVED**; verify live before relying on either tool.
- **R2 Superuser credentials.** `<I>-credentials-superuser` has no creator template; only consumers and backup declarations exist (CLI-core `:168`, POC `:164`). It was not in the `inst03` POC backup. Do not assume it is regenerable; confirm its presence and creator live.
- **R3 Backup/restore coverage is declared, not verified.** No COT backup exists; Tekton roles are unseen; the POC defaults to `inst03`/`main`; CLI-core does not declare AiCfg, AppCfg or GenericAddons; CLI-manage does not declare `cot-keys-ltpa` or the operator-generated Secrets.
- **R4 Manage JMS volume.** No tool covers PV data.
- **R5 Unevidenced items.** `ibm-truststore-mgr` Subscription, `ScimCfg`/`CoreIDP`, CSV names, and the existing report's `<I>-main-manage-status` and `metering-sls-entitlement` ConfigMaps.

### I-8 Recovery classification and ownership rules

| Class | Resources (pattern; see I-1 to I-7 for evidence) | Basis | Evidence |
|---|---|---|---|
| **State-bearing Secrets (preserve, do not assume regenerable)** | `<I>-credentials-superuser`, `<I>-keys-jwt` (core); `<W>-manage-encryption-secret`, `<W>-manage-encryption-secret-operator`, `<I>-keys-ltpa` (manage) | Key names/hints in `dr_lib.py:52`; CLI backs up superuser and encryption Secrets (core L168, manage L161-162). Regeneration consequences are inferred, not tested | PROBABLE |
| **GitOps-regenerable** | `Suite`, `Workspace`, config CRs, `ManageApp`, `ManageWorkspace`, Subscriptions, OperatorGroups, `ibm-entitlement`, config `*-credentials` Secrets, add-server-config/logging Secrets, placeholder ConfigMaps, `GenericAddon`s, RBAC | Helm templates in I-1–I-7. Secrets re-render only if their AWS SM source still exists | VERIFIED for definitions; COT enablement UNRESOLVED |
| **Operator-generated (reconcile)** | Binding Secrets/ConfigMaps, bundle/property Secrets, truststore objects, `maximo-config`, catalog/settings ConfigMaps, JMS PVC, CSVs | `ownerReferences` in the inst03 POC backup; no GitOps source. Automatic recreation is *assumed*, not demonstrated (`dr_lib.py:305`) | PROBABLE |
| **cert-manager issued** | `<I>-admindashboard-cert-internal`, `<I>-internal-manage-tls`, `<I>-internal-mobile-encryption`, `<I>-workspaceagent-tls`, `<I>-<W>-cert-public-81` | cert-manager annotations in POC backup; depends on CA Secret and issuers outside the four namespaces | PROBABLE |
| **Ephemeral hooks / CI** | `pre-jreporter-*`, `postsync-sanity-*`, hook Jobs/SAs | Hook annotations in templates | PROBABLE |

### I-9 External dependencies (reference only — not inventoried)

| Dependency | Where | Source | Why recovery needs it |
|---|---|---|---|
| AWS Secrets Manager entries (`<path:arn:aws:secretsmanager:<region>:<acct>:secret:...>`) | external | gitops-envs `.../inst03/ibm-mas-suite.yaml:5`, `ibm-mas-suite-configs.yaml`, `ibm-mas-masapp-configs.yaml`; saas-deploy-py `schemas/mas-apps.json:495` (`global_secrets_yaml`) | Source of entitlement, config credentials, add-server-config XML, and (SaaS) Manage encryption data |
| Secret `aws` in `mas-<I>-syncres` | namespace outside scope | gitops `instance-applications/000-ibm-sync-resources/templates/01-aws_Secret.yaml:6` | AVP/AWS access for syncing; Day-0 prerequisite |
| CatalogSource `ibm-operator-catalog` | `openshift-marketplace` | gitops `cluster-applications/000-ibm-operator-catalog/templates/03-ibm-operator-catalog_CatalogSource.yaml:5-6` | Subscriptions resolve through it |
| Red Hat cert-manager operator | `cert-manager-operator` | gitops `cluster-applications/010-redhat-cert-manager/templates/02-cert-manager_Subscription.yaml:5-6` | Issues TLS Secrets |
| cert-manager namespace objects (CA Certificates/Issuers/CA Secret) | `cert-manager` (Suite default `certManagerNamespace`) | gitops `130-ibm-mas-suite/templates/04-ibm-mas_Suite.yaml:24`; names seen only in the inst03 POC backup | CA continuity; policy is an open decision in the existing report |
| ClusterIssuers `mas-<I>-core-{internal,public}-issuer` | cluster-scoped | POC backup `cluster/`; CIS ClusterIssuers `<I>-cis-le-{prod,stg}` from `130-ibm-mas-suite/templates/00-8-ibm-cis_clusterissuer-*.yml` (only if `dns_provider=cis`) | Issuer for TLS Secrets |
| CRDs, ArgoCD, Mongo/SLS/DRO services, ingress | cluster / other namespaces | — | Not enumerated |

### I-10 Backup and restore tool coverage (declared lists only)

| Tool | Core declares | Manage declares | Note |
|---|---|---|---|
| cli `mascore-backup-restore.sh:166-185` | Subscription `ibm-mas-operator`; Secrets `ibm-entitlement`, `<I>-credentials-superuser`; OperatorGroup `ibm-mas-operator-group`; `Suite/<I>`; mongocfgs, kafkacfgs, jdbccfgs, slscfgs, bascfgs, workspaces, smtpcfgs, watsonstudiocfgs, objectstoragecfgs, pushnotificationcfgs, scimcfgs, idpcfgs, appconnects, humai, mviedges; each CR's `spec.config.credentials.secretName` Secret (L38-42); `<I>-cert-public` if manual certs (L58-59) | — | Restore is `oc new-project` + `oc apply` (L186-192). Not run against COT |
| cli `manage-backup-restore.sh:155-173` | jdbccfgs from core | Subscription `ibm-mas-manage`; OperatorGroup (auto-discovered); `ibm-entitlement`; `<W>-manage-encryptionsecret` and `-encryptionsecret-operator`; `ManageApp/<I>`; all `ManageWorkspace` plus referenced Secrets; `<I>-<W>-cert-public-81` if manual certs | Does not list `<I>-keys-ltpa`, binding Secrets, ConfigMaps |
| gitops POC `backup-suite-manage.sh:147-203` (allowlist) | `Suite`, 6 ConfigMaps, 3 Secrets (`keys-jwt`, `admindashboard-cert-internal`, `credentials-superuser`) | `ManageWorkspace`, 17 ConfigMaps, 24 Secrets incl. encryption pair (required) | Defaults `INSTANCE=inst03`, `WORKSPACE_ID=main` (L25-26); namespaces derived from them (L28-29). Subscriptions/OperatorGroups/CSVs are never restored (`restore.py` plan L97-106). Restore refuses the source cluster |
| cli Tekton `tasks/suite-backup`, `suite-restore`, `suite-app-backup`, `suite-app-restore` `.yml.j2` | delegate to Ansible roles via `run-role.sh` (L42, 66, 78, 86) | same | Role contents not in these repos → coverage **not verified** |
| saas-tekton | — | — | Only Db2 backup parameters (out of scope); no Suite/Manage DR pipeline found |

### I-11 Gaps and risks found by this review

1. **Encryption Secret name mismatch.** CLI manage backup uses `<W>-manage-encryptionsecret[-operator]` (`manage-backup-restore.sh:161-162`); the POC allowlist and inst03 POC backup use `<W>-manage-encryption-secret[-operator]` (`backup-suite-manage.sh:180-181`). If COT uses the hyphenated name, the CLI script would silently skip the most critical Manage state. **UNRESOLVED — verify live.**
2. **Encryption Secret creator is ambiguous.** GitOps renders it only when `global_secrets` is set (`01-ibm-manage_encryption_secret.yaml:16`); inst03 sets none, so it is operator-created there. Backing it up is only safe to skip if COT supplies it deterministically from AWS SM (UNRESOLVED).
3. **`<I>-credentials-superuser` has no creator template** and was not in the inst03 backup directory, although CLI and POC both list it. Presence must be confirmed live.
4. **No standby remapping.** The POC script has no standby mode; a standby run needs explicit `INSTANCE`/`CORE_NS`/`MANAGE_NS` overrides, which are untested. Whether standby is a separate MAS instance (`cot-sby`) is inferred only from namespace names.
5. **Citation errors in the existing report above (left unedited, noted here):** `root-applications/ibm-mas-instance-root/templates/100-ibm-mas-suite-operator.yaml` does not exist (real: `instance-applications/130-ibm-mas-suite/templates/02-ibm-mas_Subscription.yaml`); `instance-applications/510-550-ibm-manage_additional_server_config_secrets.yaml` does not exist (real: `510-550-ibm-mas-suite-app-config/templates/01-ibm-manage_additional_server_config_secrets.yaml`); OperatorGroup names `mas-inst03-core-operatorgroup`/`mas-inst03-manage-operatorgroup` do not match the templates; Subscription `ibm-mas-manage-operator` is `ibm-mas-manage`; ConfigMaps `inst03-main-manage-status` and `metering-sls-entitlement` and Subscription `ibm-truststore-mgr` have no source and are absent from the POC backup.
6. **JMS PVC data** (`mas-<I>-jmsserver-pvc` in inst03) is not covered by any inspected tool; whether its content matters for continuity is undecided.
7. **Operator RBAC for CRs** `ScimCfg`/`CoreIDP`: CLI backs up `scimcfgs`, but no GitOps source or POC evidence shows they exist.

### I-12 POC-environment (`inst03`) evidence — not proof of COT

The `inst03` material referenced above comes from the existing POC environment (cluster `noble8`, `gitops-envs/fyre-noble8-dev/noble8/inst03/`) and the local gitignored backup `poc/suite-resource-dr/backups/inst03-20261023-174100/` (README plus 54 YAML files: `core/` 9, `manage/` 39, `cert-manager/` 4, `cluster/` 2 — metadata-oriented, no MANIFEST). It shows how the Suite and Manage operators name and own objects in a comparable deployment. It does not show that any resource exists in `mas-cot-*`. The earlier `inst03` sections of this report are unchanged.

### I-13 Verified / unresolved summary

| | Items |
|---|---|
| **Verified (source)** | Namespace pattern; Suite, Workspace, config-CR, ManageApp, ManageWorkspace, GenericAddon definitions; Subscriptions `ibm-mas-operator`, `ibm-mas-manage`; OperatorGroups `ibm-mas-operator-group`, `<ns>-operator-group`; `ibm-entitlement` (both namespaces); placeholder ConfigMaps; essential Manage RBAC; `mas-application-admin` RBAC; CLI and POC backup lists |
| **Probable** | Operator-generated Secrets/ConfigMaps/PVC and cert-manager Secrets (from inst03 POC only); config-chart Secrets/CRs whose enablement for COT is unknown; all Standby names (`cot-sby` inferred) |
| **Unresolved** | COT/standby instance ID, `<W>`, channels, enabled charts, AWS SM paths; presence of every resource in COT; actual backup coverage; encryption Secret naming/creator; `ibm-truststore-mgr`; `ScimCfg`/`CoreIDP`; CSV names; Certificate objects in the four namespaces; Tekton DR role coverage; standby topology |
| **Required next step** | Run read-only discovery (`backup-suite-manage.sh --discover`, `discover.py:191-240`) against COT primary and standby, then update the Evidence and Backup columns from live output |
