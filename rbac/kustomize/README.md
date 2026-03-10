# MAS GitOps RBAC

This directory contains RBAC configurations for MAS GitOps deployments. There are two approaches available:

1. **Automated (Recommended)**: Helm chart deployed via ArgoCD when `cluster_admin_role=true`
2. **Manual**: Kustomize-based approach for pre-installation or custom scenarios

## Automated Approach (Recommended)

When deploying with `cluster_admin_role=true`, RBAC is automatically installed via the Helm chart at [`instance-applications/600-application-admin-rbac/`](../../instance-applications/600-application-admin-rbac/).

### Features

- ✅ **Automatic deployment** via ArgoCD at sync-wave 600
- ✅ **Dynamic namespace detection** - only creates RBAC for existing namespaces
- ✅ **No manual steps** required
- ✅ **Per-instance isolation** - each MAS instance gets its own RBAC

### How It Works

1. Deploy with `cluster_admin_role=true`
2. ArgoCD creates all namespaces (sync-waves 130-540)
3. ArgoCD deploys RBAC chart at sync-wave 600
4. Chart uses Helm `lookup` to detect existing namespaces
5. RBAC is created only for namespaces that exist

See [`instance-applications/600-application-admin-rbac/README.md`](../../instance-applications/600-application-admin-rbac/README.md) for details.

## Manual Approach (Kustomize)

Use this approach when:
- Pre-installing RBAC before deploying with `application_admin_role=true`
- Custom RBAC requirements
- Manual cluster setup

### Kustomize Structure

This directory contains a [Kustomize](https://kustomize.io/) structure for managing namespace-scoped RBAC for MAS GitOps deployments.

## Directory Structure

```
rbac/kustomize/
├── base/                                          # Base RBAC resources (namespace-agnostic)
│   ├── kustomization.yaml
│   ├── application-admin-role.yaml                # Role with full MAS permissions
│   └── application-admin-rolebinding.yaml         # RoleBinding template (SA patched by overlay)
├── components/
│   └── cluster-readonly/                          # Reusable component for cluster-scoped access
│       ├── kustomization.yaml
│       └── application-admin-clusterrolebinding.yaml
└── overlays/                                      # Namespace-specific overlays
    └── <service-account-name>/                    # One directory per ArgoCD service account.
        ├── kustomization.yaml                     # Top-level overlay (apply this)
        ├── db2u-<instancem-name>/
        │   └── kustomization.yaml                 # Sets namespace: db2u-<instancem-name>
        ├── mas-<instancem-name>-core/
        │   └── kustomization.yaml                 # Sets namespace: mas-<instancem-name>-core
        ├── mas-<instancem-name>-sls/
        │   └── kustomization.yaml                 # Sets namespace: mas-<instancem-name>-sls
        |── mas-<instancem-name>-manage/
        │   └── kustomization.yaml                 # Sets namespace: mas-<instancem-name>-manage
        |── mas-<instancem-name>-syncres/
        │   └── kustomization.yaml                 # Sets namespace: mas-<instancem-name>-syncres
        └── mas-<instancem-name>-visualinspection/
            └── kustomization.yaml                 # Sets namespace: mas-<instancem-name>-visualinspection
```

## Creating a New Overlay

### Step 1: Generate Overlays
Use the generator script to create overlays for your ArgoCD service account and MAS
instances.  The `--service-account` flag is **required** — there is no default value
because the correct service account depends on which ArgoCD instance you are using.

```bash
# Generate overlays (replace the SA name with your own) for each mas instance (replace dev2 with your instance names)
./rbac/generate-rbac-overlays.py \
    --service-account mas-argocd-argocd-application-controller \
    dev2
```

### Step 2: Build and Apply the Overlay

```bash
# Preview what will be applied
kustomize build rbac/kustomize/overlays/mas-argocd-argocd-application-controller

# Apply to the cluster (includes ClusterRole, Roles, RoleBindings, ClusterRoleBinding)
kubectl apply -k rbac/kustomize/overlays/mas-argocd-argocd-application-controller
```

> **Tip**: The service account name follows the pattern
> `<argocd-namespace>-argocd-application-controller`.  For example, if your ArgoCD
> instance lives in the `mas-argocd` namespace the service account name is
> `mas-argocd-argocd-application-controller`.


## How It Works

| Layer | Purpose |
|-------|---------|
| **base** | Defines the `Role` and `RoleBinding` resources without a namespace. Kustomize sets the namespace from each overlay. The RoleBinding subject uses placeholder values that **must** be patched, which is what the `generate-rbac-overlays.py` does for you  |
| **components/cluster-readonly** | A reusable Kustomize Component that adds the `ClusterRoleBinding` for read-only cluster access. Included once per service account overlay. |
| **overlays/\<sa\>/\<namespace\>** | Sets `namespace:` for the base resources, producing a `Role` and `RoleBinding` scoped to that namespace. |
| **overlays/\<sa\>** | Composes all namespace overlays and the cluster-readonly component. Patches the service account name/namespace into all bindings. |

## What Gets Built

Running `kustomize build rbac/kustomize/overlays/<service-account-name>` produces:

- `Role/mas-application-admin` in each target namespace
- `RoleBinding/mas-application-admin-binding` in each target namespace (bound to the service account)
- `ClusterRoleBinding/mas-application-admin-readonly-<service-account-name>` (cluster-wide, read-only access)

## Verify

```bash
# Check Roles and RoleBindings in a namespace
kubectl get role,rolebinding -n mas-dev2-core

# Check ClusterRoleBinding (substitute your SA name)
kubectl get clusterrolebinding \
    mas-application-admin-readonly-mas-argocd-argocd-application-controller

# Describe the Role to see permissions
kubectl describe role mas-application-admin -n mas-dev2-core
```

## Comparison: Automated vs Manual

| Aspect | Automated (Helm) | Manual (Kustomize) |
|--------|------------------|-------------------|
| **Deployment** | Automatic via ArgoCD | Manual kubectl apply |
| **Namespace Detection** | Dynamic (Helm lookup) | Static (pre-generated) |
| **Use Case** | `cluster_admin_role=true` | Pre-install or custom setup |
| **Maintenance** | Self-updating | Requires regeneration |
| **Multi-Instance** | One chart per instance | One overlay per instance |
| **Flexibility** | Standard patterns | Full customization |
| **When to Use** | Default for most deployments | Pre-install before application_admin_role |

## Deployment Scenarios

### Scenario 1: cluster_admin_role=true (Automated)

```yaml
# In your instance configuration
cluster_admin_role: true
```

**What happens:**
1. ArgoCD has cluster-admin privileges
2. ArgoCD creates all namespaces (CreateNamespace=true)
3. ArgoCD automatically deploys RBAC chart at sync-wave 600
4. RBAC is ready for future application_admin_role operations

**No manual steps required!**

### Scenario 2: Pre-install for application_admin_role (Manual)

```bash
# Step 1: Generate overlays
./rbac/generate-rbac-overlays.py \
    --service-account mas-argocd-argocd-application-controller \
    inst1 inst2

# Step 2: Apply RBAC
kubectl apply -k rbac/kustomize/overlays/mas-argocd-argocd-application-controller

# Step 3: Deploy with application_admin_role
# In your instance configuration:
# cluster_admin_role: false
# application_admin_role: true
```

**When to use:**
- Setting up RBAC before deploying MAS
- Transitioning from cluster-admin to application-admin
- Custom RBAC requirements

## Related Documentation

- **Automated Approach**: [`instance-applications/600-application-admin-rbac/README.md`](../../instance-applications/600-application-admin-rbac/README.md)
- **Generator Script**: [`rbac/generate-rbac-overlays.py`](../generate-rbac-overlays.py)
- **ArgoCD Application**: [`root-applications/ibm-mas-instance-root/templates/600-application-admin-rbac-app.yaml`](../../root-applications/ibm-mas-instance-root/templates/600-application-admin-rbac-app.yaml)
