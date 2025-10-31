# Quick Start Guide

Get AAP running on OpenShift in minutes.

## Prerequisites

1. OpenShift cluster (4.12+)
2. Cluster admin access
3. Python 3.9+ and Ansible installed

### Install Dependencies

```bash
# Clone the collection
git clone https://github.com/rhpds/rhpds.aap_multiinstance.git
cd rhpds.aap_multiinstance

# Install Python dependencies
pip3 install --user -r requirements.txt

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Build and install this collection
ansible-galaxy collection build --force
ansible-galaxy collection install rhpds-aap_multiinstance-*.tar.gz --force
```

## 5-Minute Single Instance Deployment

### Step 1: Login to OpenShift

```bash
oc login https://api.your-cluster.com:6443
```

### Step 2: Deploy AAP

```bash
ansible-playbook playbooks/deploy-single-aap.yml
```

That's it! Your AAP instance will be deployed with:
- Automation Controller
- Event-Driven Ansible
- Auto-generated admin password

### Step 3: Access AAP

Get the route:

```bash
oc get route -n aap
```

The playbook output shows your admin credentials.

## Workshop Setup (Multi-User)

Deploy AAP for 10 students:

```bash
ansible-playbook playbooks/deploy-multiuser-aap.yml -e aap_instance_count=10
```

This creates:
- `student1-aap` through `student10-aap` namespaces
- Isolated AAP instance per student
- Each with Controller + EDA

Students access their instance:

```bash
# Student 1
oc get route -n student1-aap

# Student 2
oc get route -n student2-aap
```

## Custom Deployment

Create a playbook with your settings:

```yaml
---
- name: My AAP Deployment
  hosts: localhost
  gather_facts: false
  tasks:
    - name: Deploy AAP
      ansible.builtin.include_role:
        name: rhpds.aap_multiinstance.aap_instance
      vars:
        # Your configuration
        aap_instance_name: my-aap
        aap_instance_namespace: automation
        aap_instance_version: "2.6"

        # Choose components
        aap_instance_enable_controller: true
        aap_instance_enable_eda: true
        aap_instance_enable_hub: true
        aap_instance_enable_lightspeed: false

        # Optional: Set password
        aap_instance_admin_password: "MyPassword123!"
```

Run it:

```bash
ansible-playbook my-aap-deployment.yml
```

## What Gets Deployed?

### Single Instance

```
Namespace: aap
├── AAP Operator
└── AAP Instance
    ├── Controller (web UI + API)
    ├── EDA (event-driven automation)
    └── PostgreSQL database
```

### Multi-User (3 students example)

```
student1-aap/  → Full AAP instance
student2-aap/  → Full AAP instance
student3-aap/  → Full AAP instance
```

Each namespace is completely isolated.

## Component Options

Enable/disable components as needed:

| Component | Variable | Description |
|-----------|----------|-------------|
| Controller | `aap_instance_enable_controller: true` | Web UI, API, job execution |
| EDA | `aap_instance_enable_eda: true` | Event-driven automation |
| Hub | `aap_instance_enable_hub: true` | Private content hosting |
| Lightspeed | `aap_instance_enable_lightspeed: true` | AI code assistance |

## Version Selection

Choose AAP version:

```yaml
aap_instance_version: "2.5"  # AAP 2.5
# or
aap_instance_version: "2.6"  # AAP 2.6
```

## Next Steps

- Read the [full README](README.md) for advanced configuration
- Check [example playbooks](playbooks/) for more scenarios
- Review [role defaults](roles/aap_instance/defaults/main.yml) for all options

## Cleanup

Remove single instance:

```bash
oc delete project aap
```

Remove multi-user instances:

```bash
# Remove all student instances
for i in {1..10}; do
  oc delete project student${i}-aap
done
```

## Troubleshooting

**Operator not installing?**

```bash
oc get subscription -n aap
oc get csv -n aap
```

**Instance not ready?**

```bash
oc get ansibleautomationplatform -n aap
oc describe ansibleautomationplatform aap -n aap
```

**Check pods:**

```bash
oc get pods -n aap
```

## Support

- File issues: https://github.com/rhpds/rhpds.aap_multiinstance/issues
- Internal Red Hat support: Contact RHDP team
