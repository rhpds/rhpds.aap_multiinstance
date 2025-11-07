# aap_instance Role

Deploy Ansible Automation Platform instances on OpenShift with configurable components.

## Description

This role handles:
- AAP operator installation
- Namespace creation and management
- Component configuration (Controller, EDA, Hub, Lightspeed)
- Single or multi-user deployments
- Manifest injection
- RBAC configuration for EDA

## Requirements

- OpenShift 4.12+
- Cluster admin access
- Collections:
  - `kubernetes.core`
  - `ansible.controller`

## Role Variables

See [defaults/main.yml](defaults/main.yml) for all variables.

### Key Variables

```yaml
# Instance configuration
aap_instance_name: aap
aap_instance_namespace: aap
aap_instance_version: "2.5"

# Multi-user mode
aap_instance_multi_user: false
aap_instance_count: 1

# Components
aap_instance_enable_controller: true
aap_instance_enable_eda: true
aap_instance_enable_hub: false
aap_instance_enable_lightspeed: false
```

## Dependencies

None.

## Example Playbook

### Single Instance

```yaml
- hosts: localhost
  roles:
    - role: rhpds.aap_multiinstance.aap_instance
      vars:
        aap_instance_name: production-aap
        aap_instance_version: "2.6"
```

### Multi-User Workshop

```yaml
- hosts: localhost
  roles:
    - role: rhpds.aap_multiinstance.aap_instance
      vars:
        aap_instance_multi_user: true
        aap_instance_count: 10
        aap_instance_user_prefix: "student"
```

## License

GPL-2.0-or-later

## Author

Prakhar Srivastava
