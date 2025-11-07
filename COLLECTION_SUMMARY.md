# rhpds.aap_self_service_portal Collection Summary

## Overview

New Ansible collection for deploying AAP 2.5/2.6 on OpenShift with:
- **Configurable components** - Controller, EDA, Hub, Lightspeed
- **RHDP integration** - Works with `num_users` from AgnosticV/AgDv2
- **Multi-user support** - Automatic namespace-per-user provisioning
- **Version flexibility** - AAP 2.5 or 2.6

## Collection Structure

```
rhpds.aap_self_service_portal/
├── galaxy.yml                          # Collection metadata
├── README.md                           # Full documentation
├── QUICKSTART.md                       # Quick start guide
├── CLAUDE.md                           # Git commit guidelines
├── .gitignore                          # Git ignore rules
│
├── roles/
│   └── aap_instance/                   # Main role
│       ├── defaults/main.yml           # Default variables
│       ├── vars/main.yml               # Internal variables
│       ├── meta/main.yml               # Role metadata
│       ├── README.md                   # Role documentation
│       │
│       ├── tasks/
│       │   ├── main.yml                # Entry point
│       │   ├── validate.yml            # Input validation
│       │   ├── setup_operator.yml      # AAP operator setup
│       │   ├── deploy_instance.yml     # Single instance deployment
│       │   └── deploy_multiuser.yml    # Multi-user deployment
│       │
│       └── templates/
│           └── aap_instance.yaml.j2    # AAP CR template
│
└── playbooks/                          # Example playbooks
    ├── deploy-single-aap.yml           # Single instance
    ├── deploy-multiuser-aap.yml        # Multi-user mode
    ├── deploy-full-aap.yml             # All components
    ├── deploy-eda-only.yml             # EDA only
    └── agnosticv-integration-example.yml  # RHDP integration
```

## Key Features

### 1. RHDP Integration

Automatically integrates with AgnosticV/AgnosticD v2 variables:

```yaml
# In AgnosticV common.yaml
num_users: 10
common_password: "r3dh4t1!"

# Collection automatically:
# - Detects num_users > 1 → enables multi-user mode
# - Creates AAP instance per user
# - Matches user naming: user1, user2, etc.
```

### 2. Component Selection

Enable/disable AAP components as needed:

```yaml
aap_instance_enable_controller: true   # Automation Controller
aap_instance_enable_eda: true          # Event-Driven Ansible
aap_instance_enable_hub: false         # Private Automation Hub
aap_instance_enable_lightspeed: false  # Ansible Lightspeed
```

### 3. Version Support

```yaml
aap_instance_version: "2.5"  # or "2.6"
```

### 4. Multi-User Architecture

When `num_users > 1`:

```
user1 (htpasswd/RHSSO)  →  user1-aap namespace  →  user1-aap instance
user2 (htpasswd/RHSSO)  →  user2-aap namespace  →  user2-aap instance
user3 (htpasswd/RHSSO)  →  user3-aap namespace  →  user3-aap instance
...
```

Each user gets:
- Isolated namespace
- Dedicated AAP instance
- Own admin credentials
- Selected components (Controller, EDA, Hub, Lightspeed)

## Usage Patterns

### Pattern 1: Single AAP Instance

```yaml
- name: Deploy AAP
  ansible.builtin.include_role:
    name: rhpds.aap_self_service_portal.aap_instance
  vars:
    aap_instance_version: "2.6"
    aap_instance_enable_controller: true
    aap_instance_enable_eda: true
```

### Pattern 2: RHDP Workshop

```yaml
# In AgnosticV common.yaml: num_users: 10

- name: Deploy AAP for all users
  ansible.builtin.include_role:
    name: rhpds.aap_self_service_portal.aap_instance
  vars:
    # num_users inherited from AgnosticV
    aap_instance_version: "2.6"
    aap_instance_user_prefix: "user"  # Matches htpasswd
```

### Pattern 3: Component-Specific

```yaml
# EDA only for event-driven workflows
- name: Deploy EDA
  ansible.builtin.include_role:
    name: rhpds.aap_self_service_portal.aap_instance
  vars:
    aap_instance_enable_controller: false
    aap_instance_enable_eda: true
    aap_instance_eda_create_rolebinding: true  # For K8s events
```

## Key Variables

### RHDP Integration

| Variable | Default | Source | Purpose |
|----------|---------|--------|---------|
| `num_users` | `1` | AgnosticV | Number of users/instances |
| `common_password` | `openshift` | AgnosticV | Default user password |
| `aap_instance_num_users` | `{{ num_users }}` | Auto | Instance count |
| `aap_instance_multi_user` | Auto-detect | Auto | Multi-user mode flag |

### Instance Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `aap_instance_name` | `aap` | Instance name |
| `aap_instance_namespace` | `aap` | Base namespace |
| `aap_instance_version` | `2.5` | AAP version |
| `aap_instance_user_prefix` | `user` | User naming prefix |

### Components

| Variable | Default | Component |
|----------|---------|-----------|
| `aap_instance_enable_controller` | `true` | Automation Controller |
| `aap_instance_enable_eda` | `true` | Event-Driven Ansible |
| `aap_instance_enable_hub` | `false` | Private Automation Hub |
| `aap_instance_enable_lightspeed` | `false` | Ansible Lightspeed |

## Deployment Flow

### Single Instance
1. Validate configuration
2. Create namespace
3. Install AAP operator
4. Deploy AAP instance
5. Wait for readiness
6. (Optional) Inject manifest

### Multi-User
1. Validate configuration
2. Detect `num_users > 1`
3. Build user list (user1, user2, ...)
4. For each user:
   - Create namespace (`user1-aap`, `user2-aap`, ...)
   - Install AAP operator
   - Deploy AAP instance
   - Configure components
5. Report deployment summary

## Example Outputs

### Single Instance Deployment

```
AAP Deployment Configuration:
  Version: 2.6
  Multi-user mode: False
  Number of users: 1
  User prefix: user
  Components enabled:
    - Controller: True
    - EDA: True
    - Hub: False
    - Lightspeed: False

AAP Instance 'aap' deployed successfully
Namespace: aap
Controller URL: https://aap-controller-aap.apps.cluster.com
Admin username: admin
Admin password: <generated>
```

### Multi-User Deployment

```
Deploying 10 AAP instances for multi-user environment
Matching users: ['user1', 'user2', 'user3', ... 'user10']
Instances: ['user1-aap', 'user2-aap', ... 'user10-aap']
Namespaces: ['user1-aap', 'user2-aap', ... 'user10-aap']

Multi-user AAP deployment complete
Total instances deployed: 10
Users provisioned: user1 through user10
AAP version: 2.6
```

## Differences from Original Role

### Original (`ocp4_workload_ansible_automation_platform`)
- Single instance only
- Fixed namespace
- All components or selective disable
- No multi-user support

### This Collection (`rhpds.aap_self_service_portal`)
- Single OR multi-user mode
- RHDP integration via `num_users`
- Dynamic namespace creation
- Component selection per instance
- AAP 2.5 and 2.6 support
- Resource tuning per component
- Automatic user-to-instance mapping

## Integration Points

### AgnosticV Common Variables
```yaml
# common.yaml
num_users: 10
common_password: "r3dh4t1!"
```

### RHSSO/HTPasswd Users
```
user1:password  →  user1-aap namespace
user2:password  →  user2-aap namespace
...
```

### Resource Allocation
```yaml
# Automatically scale resources based on num_users
# Reduced per-instance resources for multi-user deployments
```

## Next Steps

1. **Test deployment**
   ```bash
   ansible-playbook playbooks/deploy-single-aap.yml
   ansible-playbook playbooks/deploy-multiuser-aap.yml -e num_users=3
   ```

2. **Build collection**
   ```bash
   ansible-galaxy collection build
   ```

3. **Publish to Git**
   ```bash
   cd rhpds.aap_self_service_portal
   git init
   git add .
   git commit -m "Initial commit: AAP multi-instance collection"
   git remote add origin https://github.com/rhpds/rhpds.aap_self_service_portal.git
   git push -u origin main
   ```

4. **Integration with RHDP**
   - Add to AgnosticV workload configs
   - Test with actual num_users from catalog items
   - Validate with RHSSO/htpasswd provisioning

## Support

- **Author**: Prakhar Srivastava (psrivast@redhat.com)
- **Team**: RHDP Technical Marketing
- **Repo**: https://github.com/rhpds/rhpds.aap_self_service_portal
