# Claude Code Instructions

## Git Commit Guidelines

When creating git commits, **NEVER** add the following footer text:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Always use clean, simple commit messages without attribution to Claude or Anthropic.**

## AAP 2.6 Self-Service Portal Deployment Notes

### Critical Architecture Changes

AAP 2.6 introduces **Platform Gateway** which fundamentally changes how self-service portal integration works:

#### Route Architecture

AAP 2.6 creates **two separate routes** per instance:

1. **Gateway Route** (e.g., `user1-aap-user1-aap.apps...`)
   - Unified AAP route
   - Provides Gateway API at `/api/gateway/v1/`
   - Used for: OAuth applications, tokens, portal configuration

2. **Controller Route** (e.g., `user1-aap-controller-user1-aap.apps...`)
   - Controller-specific route
   - Provides Controller API at `/api/v2/`
   - Used for: Manifest injection, controller operations

#### OAuth and Authentication

**Legacy (AAP 2.4/2.5):**
- OAuth apps via Controller API: `/api/v2/applications/`
- Tokens via Controller API: `/api/v2/tokens/`
- Used `awx.awx.application` and `awx.awx.token` modules

**AAP 2.6 (Platform Gateway):**
- OAuth apps via Gateway API: `/api/gateway/v1/applications/`
- Tokens via Gateway API: `/api/gateway/v1/tokens/`
- Must use `ansible.builtin.uri` module with Gateway API
- Requires organization ID (fetch via `/api/gateway/v1/organizations/`)
- OAuth apps require `RS256` algorithm
- Must enable "Allow External Users to Create OAuth2 Tokens" in Platform Gateway settings

#### OAuth Application Creation Pattern

```yaml
# 1. Get organization ID
- name: Get Default organization ID from Gateway
  ansible.builtin.uri:
    url: "{{ aap_controller_url }}/api/gateway/v1/organizations/?name={{ aap_organization }}"
    method: GET
    user: "{{ aap_admin_username }}"
    password: "{{ aap_admin_password }}"
    force_basic_auth: yes
    validate_certs: "{{ aap_ssl_verify }}"
  register: _org_response

# 2. Create OAuth app with placeholder redirect (updated later)
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
      organization: "{{ _org_response.json.results[0].id }}"
      client_type: "confidential"
      authorization_grant_type: "authorization-code"
      redirect_uris: "{{ rhaap_redirect_url | default('https://placeholder.com') }}"
      algorithm: "RS256"
  register: app_result

# 3. Update OAuth app with real redirect URL after portal deployment
- name: Update OAuth2 application redirect URI
  ansible.builtin.uri:
    url: "{{ aap_controller_url }}/api/gateway/v1/applications/{{ app_id }}/"
    method: PATCH
    body_format: json
    body:
      redirect_uris: "{{ rhaap_redirect_url }}"
```

#### Portal Configuration

Portal secrets must use **Gateway route**, not controller route:

```yaml
stringData:
  # CORRECT: Gateway route
  aap-host-url: "https://user1-aap-user1-aap.apps.cluster.com"

  # Token from Gateway API
  aap-token: "{{ aap_token_result.json.token }}"

  # OAuth credentials from Gateway API
  oauth-client-id: "{{ app_result.json.client_id }}"
  oauth-client-secret: "{{ app_result.json.client_secret }}"
```

#### Multi-User Route Extraction

When deploying multiple AAP instances, extract **both** routes:

```yaml
_user_access_info:
  - user: user1
    namespace: user1-aap
    route: user1-aap-user1-aap.apps...         # Gateway route (for portal)
    controller_route: user1-aap-controller-... # Controller route (for manifest)
    password: xxx
```

Use the appropriate route for each operation:
- **Gateway route** → OAuth, tokens, portal config
- **Controller route** → Manifest injection, controller API checks

### Deployment Timing

After deploying self-service portal via Helm, wait **2 minutes** before showing URLs to users:

```yaml
- name: Wait 2 minutes for self-service portals to become ready
  ansible.builtin.pause:
    seconds: 120
```

Portals typically take 2-3 minutes to fully start up.

### Common Issues and Solutions

#### "The fields name, organization must make a unique set"
OAuth app already exists. Check before creating:
```yaml
- name: Check if OAuth2 application already exists
  ansible.builtin.uri:
    url: "{{ aap_controller_url }}/api/gateway/v1/applications/?name={{ aap_oauth_client_name | urlencode }}"
```

#### "URL can't contain control characters"
URL-encode query parameters with spaces:
```yaml
url: "{{ aap_controller_url }}/api/gateway/v1/applications/?name={{ aap_oauth_client_name | urlencode }}"
```

#### Manifest injection returns 404
Use controller route, not gateway route:
```yaml
manifest_controller_url: "https://{{ item.controller_route }}"
```

#### Portal OAuth login fails
Ensure portal uses gateway route, not controller route.

### Prerequisites Checklist

- [ ] AAP 2.6 with Platform Gateway enabled
- [ ] "Allow External Users to Create OAuth2 Tokens" enabled in Gateway settings
- [ ] Using gateway route for portal configuration
- [ ] OAuth apps created via Gateway API
- [ ] Tokens created via Gateway API

### Reference Files

- `roles/self_service/tasks/oauth.yml` - Gateway OAuth app creation
- `roles/self_service/tasks/create_token.yml` - Gateway token creation
- `roles/self_service/tasks/update_aap_oauth.yml` - OAuth redirect update
- `roles/self_service/tasks/oc_secrets.yml` - Gateway route config
- `roles/ocp4_workload_aap_multiinstance/tasks/deploy_multiuser.yml` - Dual route extraction
- `AAP_26_GATEWAY_CHANGES.md` - Detailed documentation

## AAP Self-Service Custom Content Role

### Overview

The `aap_selfservice_custom` role automatically configures demo content in AAP instances after deployment. Based on Hicham's playbook from https://github.com/ansible-tmm/ssap-lab.

**Location:** `roles/aap_selfservice_custom/`
**Maintainer:** Hicham Mourad <hmourad@redhat.com>
**Collection Version:** 1.1.0+

### What It Does

Configures each AAP instance with:
- **3 demo users:** clouduser1, networkuser1, rheluser1 (using workshop `common_password`)
- **5 inventories:** AWS, Azure, GCP, RHEL, Network
- **5 credentials:** Placeholder values for CNV/demo environments
- **1 SCM project:** ansible-tmm/ssap-lab (main branch)
- **4 labels:** aws, rhel, network, custom
- **15 job templates:** 5 AWS + 4 Network + 6 RHEL

### Architecture

**Data Flow:**
1. `ocp4_workload_aap_multiinstance` saves AAP instance data via `agnosticd_user_info`
2. `aap_selfservice_custom` retrieves data via `lookup('agnosticd_user_data')`
3. Role loops through all AAP instances (multi-user mode) or configures single instance

**Key Technical Details:**
- Uses `ansible.controller` collection modules (available in execution environment)
- Connects via **Gateway route** (AAP 2.6 architecture)
- Health check endpoint: `/api/gateway/v1/` (not `/api/v2/ping/`)
- Idempotent: safe to re-run, skips existing resources
- Loop variable: `aap_instance` (avoids collision with inner loops)

### Important Fixes Applied

#### Fix 1: Gateway API Health Check
**Problem:** Used `/api/v2/ping/` which returns 404 on gateway route
**Solution:** Changed to `/api/gateway/v1/` for AAP 2.6 compatibility
```yaml
# roles/aap_selfservice_custom/tasks/setup_instance_content.yml:25
url: "{{ aap_selfservice_custom_controller_url }}/api/gateway/v1/"
```

#### Fix 2: Loop Variable Collision
**Problem:** Outer loop used `item`, inner loops also used `item`, causing template resolution errors
**Solution:** Added `loop_var: aap_instance` to outer loop
```yaml
# roles/aap_selfservice_custom/tasks/main.yml:94-95
loop_control:
  loop_var: aap_instance
  label: "{{ aap_instance.user }} - {{ aap_instance.route }}"
```

#### Fix 3: Manifest Injection Certificate Validation
**Problem:** `validate_certs: true` failed in CNV with self-signed certs
**Solution:** Changed to `validate_certs: false` in inject_manifest.yml
```yaml
# roles/ocp4_workload_aap_multiinstance/tasks/inject_manifest.yml:29,42
validate_certs: false
```

### Configuration Variables

All demo content is defined in `roles/aap_selfservice_custom/defaults/main.yml`:

```yaml
# Demo users with workshop password
aap_selfservice_custom_user_password: "{{ common_password }}"
aap_selfservice_custom_users:
  - username: clouduser1
    password: "{{ aap_selfservice_custom_user_password }}"
    ...

# Placeholder credentials for CNV environments
aap_selfservice_custom_credentials:
  - name: AWS Credentials
    credential_type: Amazon Web Services
    inputs:
      username: "blahblahblahAWSACCESSKEYID"
      password: "blahblahlahAWSSECRETACCESSKEY"
  ...
```

### Customization for Hicham

**To modify demo content:**

1. **Edit defaults/main.yml:**
   ```yaml
   # Add/remove users
   aap_selfservice_custom_users:
     - username: newuser1
       password: "{{ aap_selfservice_custom_user_password }}"
       email: newuser1@example.com
       first_name: New
       last_name: User1

   # Add/modify job templates
   aap_selfservice_custom_job_templates:
     - name: My Custom Template
       playbook: my_playbook.yml
       inventory: RHEL Inventory
       credentials:
         - RHEL - SSH Credentials
       labels:
         - custom
   ```

2. **Or override in AgnosticV workshop config:**
   ```yaml
   # agd_v2/aap-multiinstance-workshop/common.yaml
   aap_selfservice_custom_projects:
     - name: Custom Project
       scm_url: https://github.com/my-org/my-playbooks
       scm_branch: main
   ```

3. **CNV Environment Notes:**
   - Credentials use placeholder values (fake AWS/Azure keys)
   - Job templates appear in UI but won't execute against real infrastructure
   - Perfect for portal UI demonstrations

### Troubleshooting

**Role skipped - no AAP instances found:**
- Check `ocp4_workload_aap_multiinstance` ran successfully
- Verify `agnosticd_user_info` data was saved

**Connection errors to AAP:**
- Ensure using gateway route (not controller route)
- Verify `/api/gateway/v1/` is accessible
- Check admin credentials are correct

**Job template creation fails:**
- Wait for project SCM sync (role includes 30s pause)
- Verify playbook names exist in SCM repository
- Check inventory and credential names match exactly

**Loop variable warnings:**
- Should be resolved with `loop_var: aap_instance`
- If reoccurs, check for nested `include_tasks` with loops
