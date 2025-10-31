# Testing Guide for rhpds.aap_multiinstance

## Pre-requisites

### 1. OpenShift Cluster Access
```bash
# Login to your cluster
oc login https://api.your-cluster.com:6443

# Verify you're logged in
oc whoami
oc cluster-info

# Check you have cluster-admin
oc auth can-i '*' '*'
```

### 2. Install Collection Dependencies
```bash
# Install required collections
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install ansible.controller

# Verify Python dependencies
pip install kubernetes openshift
```

### 3. Install This Collection
```bash
# Option 1: Install from local directory
cd /Users/psrivast/work/code
ansible-galaxy collection install ./rhpds.aap_multiinstance

# Option 2: Install from Git (after pushed)
ansible-galaxy collection install git+ssh://git@github.com/rhpds/rhpds.aap_multiinstance.git

# Option 3: Use ANSIBLE_COLLECTIONS_PATH
export ANSIBLE_COLLECTIONS_PATH=/Users/psrivast/work/code:~/.ansible/collections
```

## Test Scenarios

### Test 1: Single AAP Instance (Basic)

**Objective**: Deploy single AAP 2.6 with Controller + EDA

```bash
cd /Users/psrivast/work/code/rhpds.aap_multiinstance

# Run deployment
ansible-playbook playbooks/deploy-single-aap.yml

# Expected: ~10-15 minutes
```

**Verify**:
```bash
# Check namespace
oc get project aap

# Check operator
oc get csv -n aap
oc get subscription -n aap

# Check AAP instance
oc get ansibleautomationplatform -n aap
oc describe ansibleautomationplatform aap -n aap

# Check pods (should see controller, eda, postgres)
oc get pods -n aap

# Get route
oc get route -n aap
```

**Success Criteria**:
- ✅ Namespace `aap` created
- ✅ AAP operator installed (CSV in "Succeeded" state)
- ✅ AAP instance status shows "Successful"
- ✅ Controller pods running
- ✅ EDA pods running
- ✅ Route accessible

### Test 2: Multi-User Deployment (RHDP Pattern)

**Objective**: Deploy 3 AAP instances using `num_users` variable

```bash
cd /Users/psrivast/work/code/rhpds.aap_multiinstance

# Run multi-user deployment
ansible-playbook playbooks/deploy-multiuser-aap.yml -e num_users=3

# Expected: ~30-40 minutes (3 parallel deployments)
```

**Verify**:
```bash
# Check all namespaces created
oc get project | grep user

# Expected output:
# user1-aap
# user2-aap
# user3-aap

# Check each instance
for i in {1..3}; do
  echo "=== Checking user${i}-aap ==="
  oc get ansibleautomationplatform -n user${i}-aap
  oc get pods -n user${i}-aap | grep -E "controller|eda"
  oc get route -n user${i}-aap
  echo ""
done
```

**Success Criteria**:
- ✅ 3 namespaces created (`user1-aap`, `user2-aap`, `user3-aap`)
- ✅ Each namespace has AAP operator
- ✅ Each namespace has AAP instance
- ✅ All instances show "Successful" status
- ✅ Isolated resources per user

### Test 3: Component Selection (EDA Only)

**Objective**: Deploy only EDA component with cluster-admin access

```bash
cd /Users/psrivast/work/code/rhpds.aap_multiinstance

ansible-playbook playbooks/deploy-eda-only.yml
```

**Verify**:
```bash
# Check namespace
oc get project aap-eda

# Check AAP instance spec
oc get ansibleautomationplatform aap-eda -n aap-eda -o yaml | grep -A5 "controller:\|eda:\|hub:"

# Should show:
#   controller:
#     disabled: true
#   eda:
#     disabled: false
#   hub:
#     disabled: true

# Check only EDA pods are running (no controller)
oc get pods -n aap-eda

# Check cluster rolebinding
oc get clusterrolebinding | grep eda
```

**Success Criteria**:
- ✅ Only EDA pods running (no controller pods)
- ✅ EDA has cluster-admin rolebinding
- ✅ Can access EDA UI via route

### Test 4: Full AAP Deployment (All Components)

**Objective**: Deploy all components (Controller, EDA, Hub, Lightspeed)

**NOTE**: Requires AAP manifest file

```bash
cd /Users/psrivast/work/code/rhpds.aap_multiinstance

# Set manifest URL
ansible-playbook playbooks/deploy-full-aap.yml \
  -e manifest_url=https://your-manifest-location/manifest.zip

# Or skip manifest injection for testing
ansible-playbook playbooks/deploy-full-aap.yml \
  -e aap_instance_inject_manifest=false
```

**Verify**:
```bash
# Check all components
oc get pods -n aap-full | grep -E "controller|eda|hub"

# Check AAP instance shows all components
oc get ansibleautomationplatform aap-full -n aap-full -o yaml | grep disabled
```

**Success Criteria**:
- ✅ Controller pods running
- ✅ EDA pods running
- ✅ Hub pods running
- ✅ Lightspeed pods running
- ✅ All routes created

### Test 5: AgnosticV Integration Pattern

**Objective**: Test with AgnosticV-style variables

```bash
cd /Users/psrivast/work/code/rhpds.aap_multiinstance

# Simulate AgnosticV common variables
ansible-playbook playbooks/agnosticv-integration-example.yml \
  -e num_users=5 \
  -e common_password="r3dh4t1!"
```

**Verify**:
```bash
# Check 5 user namespaces
oc get project | grep user.*-aap

# Should show user1-aap through user5-aap
```

**Success Criteria**:
- ✅ 5 AAP instances deployed
- ✅ Namespaces match user pattern
- ✅ All instances operational

## Cleanup After Testing

### Clean Single Instance
```bash
oc delete project aap
oc delete project aap-eda
oc delete project aap-full
```

### Clean Multi-User Instances
```bash
# Delete all user instances
for i in {1..10}; do
  oc delete project user${i}-aap --wait=false
done

# Or delete all at once
oc get project | grep user.*-aap | awk '{print $1}' | xargs oc delete project
```

## Troubleshooting

### Operator Installation Issues

```bash
# Check operator logs
oc logs -n aap deployment/aap-operator-controller-manager

# Check install plan
oc get installplan -n aap

# If stuck, check events
oc get events -n aap --sort-by='.lastTimestamp'
```

### AAP Instance Not Ready

```bash
# Check AAP instance status
oc describe ansibleautomationplatform aap -n aap

# Check operator reconciliation
oc logs -n aap deployment/aap-operator-controller-manager --tail=100

# Check pod status
oc get pods -n aap
oc describe pod <pod-name> -n aap
```

### Resource Issues

```bash
# Check cluster resources
oc describe node | grep -A5 "Allocated resources"

# Check PVCs
oc get pvc -n aap

# Check events for scheduling issues
oc get events -n aap | grep -i warning
```

### Multi-User Deployment Slow

This is expected - deploying multiple instances takes time:
- 3 users: ~30-40 minutes
- 5 users: ~45-60 minutes
- 10 users: ~60-90 minutes

Each instance deploys sequentially to avoid overwhelming the cluster.

## Performance Validation

### Check Resource Usage

```bash
# CPU and Memory per namespace
oc adm top pods -n aap

# Overall cluster usage
oc adm top nodes
```

### Access AAP UI

```bash
# Get route
ROUTE=$(oc get route -n aap -o jsonpath='{.items[0].spec.host}')
echo "AAP URL: https://${ROUTE}"

# Get admin credentials (from playbook output or secret)
oc get secret aap-admin-password -n aap -o jsonpath='{.data.password}' | base64 -d
echo ""
```

## Test Matrix

| Test | Single | Multi-User | Component Selection | RHDP Integration |
|------|--------|------------|---------------------|------------------|
| Test 1 | ✅ | - | - | - |
| Test 2 | - | ✅ | - | ✅ |
| Test 3 | ✅ | - | ✅ | - |
| Test 4 | ✅ | - | ✅ | - |
| Test 5 | - | ✅ | - | ✅ |

## Success Checklist

- [ ] Single instance deploys successfully
- [ ] Multi-user mode creates correct number of instances
- [ ] Each user gets isolated namespace
- [ ] Component selection works (Controller, EDA, Hub, Lightspeed)
- [ ] AAP 2.5 and 2.6 both work
- [ ] `num_users` variable triggers multi-user mode
- [ ] User prefix customization works
- [ ] Routes are accessible
- [ ] Operator installs correctly
- [ ] All pods reach Running state
- [ ] Manifest injection works (if tested)
- [ ] EDA cluster rolebinding works (if tested)

## Next Steps After Testing

1. Document any issues found
2. Adjust resource requests/limits based on cluster capacity
3. Create optimized defaults for RHDP workshops
4. Build collection tarball: `ansible-galaxy collection build`
5. Publish to Automation Hub or internal registry
