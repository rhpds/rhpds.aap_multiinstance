# rhpds.aap_multiinstance

Deploy single or multiple Ansible Automation Platform (AAP) 2.5/2.6 instances on OpenShift with configurable components.

## Overview

This collection provides flexible AAP deployment on OpenShift:

- **Single instance** - One AAP deployment with all or selected components
- **Multi-user mode** - Multiple isolated AAP instances for training/workshops
- **Configurable components** - Enable/disable Controller, EDA, Hub, Lightspeed
- **Version support** - AAP 2.5 or 2.6

## Features

- Modular component selection (Controller, EDA, Hub, Lightspeed)
- Multi-user deployments with namespace isolation
- Automatic admin password generation
- Optional manifest injection
- Configurable resource requests/limits
- Support for catalog snapshots
- EDA cluster rolebinding for Kubernetes event sources

## Requirements

- OpenShift 4.12+
- Cluster admin privileges
- AAP subscription/manifest (for production use)
- Python 3.9+

### Python Dependencies

Install Python dependencies:

```bash
pip3 install --user -r requirements.txt
```

Or manually:
```bash
pip3 install --user kubernetes openshift
```

### Ansible Collections

Install required collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

Or manually:
```bash
ansible-galaxy collection install kubernetes.core
```

## Installation

### From Git

```bash
ansible-galaxy collection install git+https://github.com/rhpds/rhpds.aap_multiinstance.git
```

### From Source

```bash
# Clone the repository
git clone https://github.com/rhpds/rhpds.aap_multiinstance.git
cd rhpds.aap_multiinstance

# Install dependencies
pip3 install --user -r requirements.txt
ansible-galaxy collection install -r requirements.yml

# Build and install the collection
ansible-galaxy collection build --force
ansible-galaxy collection install rhpds-aap_multiinstance-*.tar.gz --force
```

## Quick Start

### Prerequisites

1. Login to your OpenShift cluster:
```bash
oc login https://api.your-cluster.com:6443
```

2. Verify you have cluster-admin access:
```bash
oc auth can-i '*' '*'
```

### Single AAP Instance

Use the provided playbook:

```bash
cd rhpds.aap_multiinstance
ansible-playbook playbooks/deploy-single-aap.yml
```

Or create your own playbook:

```yaml
---
- name: Deploy AAP
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Deploy AAP instance
      ansible.builtin.include_role:
        name: rhpds.aap_multiinstance.aap_instance
      vars:
        aap_instance_name: aap
        aap_instance_namespace: aap
        aap_instance_version: "2.5"
        aap_instance_enable_controller: true
        aap_instance_enable_eda: true
        aap_instance_enable_hub: false
        aap_instance_enable_lightspeed: false
```

### Multi-User Deployment (RHDP Integration)

Use the provided playbook:

```bash
cd rhpds.aap_multiinstance

# Deploy for 3 users
ansible-playbook playbooks/deploy-multiuser-aap.yml -e num_users=3

# Deploy for 10 users
ansible-playbook playbooks/deploy-multiuser-aap.yml -e num_users=10
```

Or create your own playbook:

```yaml
---
- name: Deploy multi-user AAP
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Deploy AAP instances
      ansible.builtin.include_role:
        name: rhpds.aap_multiinstance.aap_instance
      vars:
        # Set num_users - automatically enables multi-user mode when > 1
        num_users: 5  # Or from AgnosticV common.yaml

        aap_instance_user_prefix: "user"  # Matches htpasswd users
        aap_instance_name: aap
        aap_instance_namespace: aap
        aap_instance_version: "2.6"
        aap_instance_enable_controller: true
        aap_instance_enable_eda: true
```

This creates AAP instances matching user accounts:
- `user1` → `user1-aap` namespace with `user1-aap` instance
- `user2` → `user2-aap` namespace with `user2-aap` instance
- ... through `user5-aap`

**Note**: The `num_users` variable integrates with RHDP's htpasswd/RHSSO user provisioning pattern.

## Configuration Variables

### Instance Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_instance_name` | `aap` | Instance name |
| `aap_instance_namespace` | `aap` | Deployment namespace |
| `aap_instance_version` | `2.5` | AAP version (2.5 or 2.6) |

### Multi-User Mode (RHDP Integration)

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_instance_num_users` | `{{ num_users \| default(1) }}` | Number of users (from RHDP `num_users` variable) |
| `aap_instance_multi_user` | Auto-detected | Auto-enables when `num_users > 1` |
| `aap_instance_user_prefix` | `user` | User prefix (must match htpasswd/RHSSO) |
| `aap_instance_user_password` | `{{ common_password \| default('openshift') }}` | User password (from RHDP `common_password`) |

**Key Integration Points:**
- `num_users` variable from AgnosticV/AgDv2 automatically controls instance count
- When `num_users > 1`, multi-user mode activates automatically
- User naming matches RHDP pattern: `user1`, `user2`, etc.
- Each user gets isolated AAP instance: `user1-aap`, `user2-aap`, etc.

### Component Toggles

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_instance_enable_controller` | `true` | Enable Automation Controller |
| `aap_instance_enable_eda` | `true` | Enable Event-Driven Ansible |
| `aap_instance_enable_hub` | `false` | Enable Private Automation Hub |
| `aap_instance_enable_lightspeed` | `false` | Enable Ansible Lightspeed |

### Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `aap_instance_admin_username` | `admin` | Admin username |
| `aap_instance_admin_password` | `""` | Admin password (auto-generated if empty) |
| `aap_instance_admin_password_length` | `16` | Password length if auto-generated |

### Resource Configuration

#### Controller Resources

```yaml
aap_instance_controller_replicas: 1
aap_instance_controller_web_replicas: 1
aap_instance_controller_task_replicas: 1

aap_instance_controller_web_resource_requirements:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

#### EDA Resources

```yaml
aap_instance_eda_replicas: 1
aap_instance_eda_resource_requirements:
  requests:
    cpu: 250m
    memory: 1Gi
  limits:
    cpu: 1000m
    memory: 2Gi
```

#### Hub Resources

```yaml
aap_instance_hub_replicas: 1
aap_instance_hub_content_workers: 2
aap_instance_hub_api_workers: 2
aap_instance_hub_file_storage_size: 100Gi
aap_instance_hub_file_storage_access_mode: ReadWriteOnce
aap_instance_hub_file_storage_class: ""
```

### Manifest Injection

```yaml
aap_instance_inject_manifest: true
aap_instance_manifest:
  url: "https://example.com/manifest.zip"
  username: ""  # optional
  password: ""  # optional
```

### EDA Cluster Permissions

```yaml
aap_instance_eda_create_rolebinding: true
aap_instance_eda_service_account: default
aap_instance_eda_cluster_role: cluster-admin
```

## Usage Examples

### AAP 2.6 with All Components

```yaml
- name: Full AAP deployment
  ansible.builtin.include_role:
    name: rhpds.aap_multiinstance.aap_instance
  vars:
    aap_instance_version: "2.6"
    aap_instance_enable_controller: true
    aap_instance_enable_eda: true
    aap_instance_enable_hub: true
    aap_instance_enable_lightspeed: true
    aap_instance_inject_manifest: true
    aap_instance_manifest:
      url: "{{ manifest_url }}"
```

### Controller-Only Deployment

```yaml
- name: Controller only
  ansible.builtin.include_role:
    name: rhpds.aap_multiinstance.aap_instance
  vars:
    aap_instance_enable_controller: true
    aap_instance_enable_eda: false
    aap_instance_enable_hub: false
    aap_instance_enable_lightspeed: false
```

### EDA with Kubernetes Event Sources

```yaml
- name: EDA with cluster access
  ansible.builtin.include_role:
    name: rhpds.aap_multiinstance.aap_instance
  vars:
    aap_instance_enable_controller: false
    aap_instance_enable_eda: true
    aap_instance_eda_create_rolebinding: true
```

### Workshop Setup (10 Students with RHDP)

```yaml
- name: Workshop AAP instances
  ansible.builtin.include_role:
    name: rhpds.aap_multiinstance.aap_instance
  vars:
    # num_users typically comes from AgnosticV common.yaml
    num_users: 10

    # User prefix matches your htpasswd/RHSSO config
    aap_instance_user_prefix: "user"

    aap_instance_version: "2.6"
    aap_instance_enable_controller: true
    aap_instance_enable_eda: true

    # Reduced resources for workshop
    aap_instance_controller_web_resource_requirements:
      requests:
        cpu: 250m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi
```

This creates 10 AAP instances matching RHDP user accounts.

## Architecture

### Single Instance Mode

```
Namespace: aap
├── AAP Operator (subscription)
├── OperatorGroup
└── AnsibleAutomationPlatform CR
    ├── Controller (if enabled)
    ├── EDA (if enabled)
    ├── Hub (if enabled)
    └── Lightspeed (if enabled)
```

### Multi-User Mode

```
Namespace: student1-aap
├── AAP Operator
├── OperatorGroup
└── AnsibleAutomationPlatform CR

Namespace: student2-aap
├── AAP Operator
├── OperatorGroup
└── AnsibleAutomationPlatform CR

... (up to aap_instance_count)
```

## Advanced Configuration

### Using Catalog Snapshots

For controlled operator versions:

```yaml
aap_instance_use_catalog_snapshot: true
aap_instance_catalogsource_name: olm-snapshot-redhat-catalog
aap_instance_catalog_snapshot_image: quay.io/gpte-devops-automation/olm_snapshot_redhat_catalog
aap_instance_catalog_snapshot_image_tag: v4.19_2025_09_29
```

### Custom Storage Class for Hub

```yaml
aap_instance_enable_hub: true
aap_instance_hub_file_storage_class: ocs-storagecluster-cephfs
aap_instance_hub_file_storage_size: 200Gi
```

### Extended Token Lifecycle

```yaml
# 4 weeks instead of default 2 weeks
aap_instance_ocp_token_lifecycle: 2419200
```

## Troubleshooting

### Check Operator Installation

```bash
oc get csv -n aap
oc get subscription -n aap
```

### Check AAP Instance Status

```bash
oc get ansibleautomationplatform -n aap
oc describe ansibleautomationplatform aap -n aap
```

### Check Component Pods

```bash
oc get pods -n aap
```

### View Controller Logs

```bash
oc logs -n aap deployment/aap-controller-web
```

### Common Issues

**Operator not installing**
- Check subscription and catalog source
- Verify cluster has internet access (or catalog snapshot is configured)

**Instance stuck in deploying state**
- Check operator logs: `oc logs -n aap deployment/aap-operator-controller-manager`
- Verify resource quotas and limits

**Manifest upload fails**
- Ensure controller is fully ready before manifest injection
- Check manifest URL is accessible
- Verify manifest is valid for AAP version

## Development

### Testing

```bash
# Deploy test instance
ansible-playbook tests/deploy-single.yml

# Deploy multi-user test
ansible-playbook tests/deploy-multiuser.yml

# Cleanup
ansible-playbook tests/cleanup.yml
```

### Building Collection

```bash
ansible-galaxy collection build
```

## License

GPL-2.0-or-later

## Author

Prakhar Srivastava (psrivast@redhat.com)
Manager, Technical Marketing - Red Hat

## Support

- Issues: https://github.com/rhpds/rhpds.aap_multiinstance/issues
- RHDP Documentation: Internal Red Hat resources
