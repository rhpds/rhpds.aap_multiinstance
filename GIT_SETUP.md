# Git Setup Instructions

## Initialize and Push to GitHub (SSH)

```bash
# Navigate to the collection directory
cd /Users/psrivast/work/code/rhpds.aap_self_service_portal

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: AAP multi-instance collection with RHDP integration"

# Add remote using SSH
git remote add origin git@github.com:rhpds/rhpds.aap_self_service_portal.git

# Create main branch and push
git branch -M main
git push -u origin main
```

## Verify SSH Setup

Before pushing, ensure your SSH key is configured:

```bash
# Test GitHub SSH connection
ssh -T git@github.com

# Expected output:
# Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

## Create GitHub Repository First

If the repository doesn't exist yet, create it on GitHub:

1. Go to https://github.com/rhpds
2. Click "New repository"
3. Name: `rhpds.aap_self_service_portal`
4. Description: "Multi-instance Ansible Automation Platform deployment for OpenShift"
5. Keep it **Public** (or Private if needed)
6. **Do NOT** initialize with README, .gitignore, or license (we already have these)
7. Click "Create repository"

Then run the commands above.

## Alternative: If Repository Already Exists

If you already created the repo on GitHub:

```bash
cd /Users/psrivast/work/code/rhpds.aap_self_service_portal

# Clone the empty repo (this creates the .git directory)
git clone git@github.com:rhpds/rhpds.aap_self_service_portal.git temp_clone
mv temp_clone/.git .
rm -rf temp_clone

# Add all files
git add .

# Commit
git commit -m "Initial commit: AAP multi-instance collection with RHDP integration"

# Push to main
git branch -M main
git push -u origin main
```

## Subsequent Updates

After the initial push, use:

```bash
# Make your changes
# ...

# Stage changes
git add .

# Commit with descriptive message
git commit -m "Add support for AAP 2.7"

# Push
git push
```

## Common Issues

### SSH Key Not Configured

If you get "Permission denied (publickey)":

```bash
# Generate new SSH key (if needed)
ssh-keygen -t ed25519 -C "psrivast@redhat.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub: Settings → SSH and GPG keys → New SSH key
```

### Wrong Remote URL

If you accidentally used HTTPS:

```bash
# Check current remote
git remote -v

# Remove HTTPS remote
git remote remove origin

# Add SSH remote
git remote add origin git@github.com:rhpds/rhpds.aap_self_service_portal.git
```
