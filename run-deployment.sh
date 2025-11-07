#!/bin/bash
# Simple deployment script for AAP multi-instance

set -e

# Check if num_users is provided
NUM_USERS=${1:-3}

echo "========================================="
echo "AAP Multi-User Deployment"
echo "========================================="
echo "Number of users: ${NUM_USERS}"
echo "Using EE: quay.io/agnosticd/ee-multicloud-custom:andrew.0.1"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Collection path: ${SCRIPT_DIR}"
echo ""

# Run with podman
podman run --rm -it \
  -v ${SCRIPT_DIR}:/runner/rhpds.aap_self_service_portal:Z \
  -v ~/.kube:/home/runner/.kube:Z \
  -e KUBECONFIG=/home/runner/.kube/config \
  -e ANSIBLE_COLLECTIONS_PATH=/runner \
  quay.io/agnosticd/ee-multicloud-custom:andrew.0.1 \
  ansible-playbook /runner/rhpds.aap_self_service_portal/playbooks/deploy-multiuser-aap.yml \
  -e num_users=${NUM_USERS} \
  -v

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
