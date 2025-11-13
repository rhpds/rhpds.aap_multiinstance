# AAP 2.6 Gateway Changes

## Overview

AAP 2.6 introduces the **Platform Gateway** component which replaces the legacy Controller OAuth system. This document explains the changes required for self-service portal deployment.

## Key Changes

### 1. Gateway Component Required

AAP 2.6 deployments must include the **Platform Gateway** component for the self-service portal to function. The gateway provides:

- Unified API endpoint (`/api/gateway/v1/`)
- Modern OAuth 2.0 implementation
- Centralized authentication and authorization

### 2. OAuth Applications

**Before (AAP 2.4/2.5 - Legacy)**:
- OAuth apps created via Controller API: `/api/v2/applications/`
- Used `awx.awx.application` Ansible module
- Apps appeared in "Legacy Applications" section

**After (AAP 2.6 - Gateway)**:
- OAuth apps created via Gateway API: `/api/gateway/v1/applications/`
- Must use `ansible.builtin.uri` module
- Requires organization ID
- Uses `RS256` algorithm

### 3. Personal Access Tokens

**Before (Legacy)**:
- Tokens created via `/api/v2/tokens/`
- Used `awx.awx.token` module

**After (AAP 2.6 - Gateway)**:
- Tokens created via `/api/gateway/v1/tokens/`
- Must use `ansible.builtin.uri` module
- Tokens work with both Controller and Gateway APIs

### 4. Portal Configuration

**Critical**: The portal must be configured with the **Gateway route**, not the controller-specific route.

**Wrong**: `https://user1-aap-controller-user1-aap.apps.example.com` (Controller route)
**Correct**: `https://user1-aap-user1-aap.apps.example.com` (Gateway route)

The unified AAP route points to the gateway service which provides access to all AAP components.

## Implementation Details

### OAuth Application Creation

```yaml
- name: Get Default organization ID from Gateway
  ansible.builtin.uri:
    url: "{{ aap_controller_url }}/api/gateway/v1/organizations/?name={{ aap_organization }}"
    method: GET
    user: "{{ aap_admin_username }}"
    password: "{{ aap_admin_password }}"
    force_basic_auth: yes
    validate_certs: "{{ aap_ssl_verify }}"
  register: _org_response

- name: Create OAuth2 application in AAP Gateway
  ansible.builtin.uri:
    url: "{{ aap_controller_url }}/api/gateway/v1/applications/"
    method: POST
    user: "{{ aap_admin_username }}"
    password: "{{ aap_admin_password }}"
    force_basic_auth: yes
    validate_certs: "{{ aap_ssl_verify }}"
    body_format: json
    body:
      name: "{{ aap_oauth_client_name }}"
      description: "Self Service Portal OAuth Application"
      organization: "{{ _org_response.json.results[0].id }}"
      client_type: "confidential"
      authorization_grant_type: "authorization-code"
      redirect_uris: "{{ rhaap_redirect_url }}"
      algorithm: "RS256"
  register: app_result
```

### Token Creation

```yaml
- name: Create AAP Gateway personal access token
  ansible.builtin.uri:
    url: "{{ aap_controller_url }}/api/gateway/v1/tokens/"
    method: POST
    user: "{{ aap_admin_username }}"
    password: "{{ aap_admin_password }}"
    force_basic_auth: yes
    validate_certs: "{{ aap_ssl_verify }}"
    body_format: json
    body:
      description: "Self Service Portal Backend Token"
      scope: "read"
  register: aap_token_result
```

### Secret Configuration

```yaml
stringData:
  # Use Gateway URL, not controller-specific route
  aap-host-url: "{{ aap_controller_url }}"
  # Token from Gateway API response
  aap-token: "{{ aap_token_result.json.token }}"
  # OAuth credentials from Gateway API response
  oauth-client-id: "{{ app_result.json.client_id }}"
  oauth-client-secret: "{{ app_result.json.client_secret }}"
```

## Prerequisites

### Platform Gateway Settings

Before deploying the portal, ensure the following AAP setting is enabled:

**Settings → Platform gateway → Allow External Users to Create OAuth2 Tokens: Enabled**

This can be verified/set via:
1. Log into AAP as admin
2. Navigate to Settings → Platform gateway
3. Enable "Allow external users to create OAuth2 tokens"

## Troubleshooting

### OAuth Login Fails with "Invalid client_id"

**Cause**: OAuth application doesn't exist in Gateway API
**Solution**: Verify OAuth app exists in `/api/gateway/v1/applications/`, not just in legacy controller apps

### Catalog Sync Shows "Unauthorized" Errors

**Cause**: Token authentication issue with Gateway API
**Solution**: Ensure token was created via `/api/gateway/v1/tokens/` endpoint

### Portal Shows "Not Found" for Organizations

**Cause**: Portal is pointing to controller route instead of gateway route
**Solution**: Update `aap-host-url` in secrets to use the unified AAP route (gateway)

## Related Files Changed

- `roles/self_service/tasks/oauth.yml` - OAuth app creation via Gateway API
- `roles/self_service/tasks/create_token.yml` - Token creation via Gateway API
- `roles/self_service/tasks/oc_secrets.yml` - Use Gateway URL and Gateway API response format
- `roles/ocp4_workload_aap_multiinstance/tasks/deploy_multiuser.yml` - Extract gateway route instead of controller route
- `roles/ocp4_workload_aap_multiinstance/tasks/workload.yml` - Include portal URL in user info output

## References

- [AAP 2.6 Installation Guide](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/)
- [Gateway OAuth Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html/access_management_and_authentication/gw-token-based-authentication)
