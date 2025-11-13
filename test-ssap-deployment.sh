#!/bin/bash
# Self-Service Portal (SSAP) Deployment Test Script
# Tests AAP multi-instance and portal deployment

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NUM_USERS=${NUM_USERS:-3}
NAMESPACE_PREFIX="user"

echo "======================================"
echo "SSAP Deployment Test"
echo "======================================"
echo ""

# Test 1: Check AAP Controller Namespaces
echo -e "${YELLOW}Test 1: Checking AAP Controller Namespaces${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-controller"
    if oc get namespace $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}✓${NC} Namespace $NAMESPACE exists"
    else
        echo -e "${RED}✗${NC} Namespace $NAMESPACE not found"
    fi
done
echo ""

# Test 2: Check AAP Controller Pods
echo -e "${YELLOW}Test 2: Checking AAP Controller Pods${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-controller"
    POD_COUNT=$(oc get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    RUNNING_COUNT=$(oc get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    echo "  $NAMESPACE: $RUNNING_COUNT/$POD_COUNT pods running"
done
echo ""

# Test 3: Check AAP Controller Routes
echo -e "${YELLOW}Test 3: Checking AAP Controller Routes${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-controller"
    ROUTE=$(oc get route -n $NAMESPACE -l app.kubernetes.io/component=automationcontroller -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "Not found")
    if [ "$ROUTE" != "Not found" ]; then
        echo -e "${GREEN}✓${NC} $NAMESPACE route: https://$ROUTE"
    else
        echo -e "${RED}✗${NC} $NAMESPACE route not found"
    fi
done
echo ""

# Test 4: Check SSAP Namespaces
echo -e "${YELLOW}Test 4: Checking SSAP Namespaces${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-ssap"
    if oc get namespace $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}✓${NC} Namespace $NAMESPACE exists"
    else
        echo -e "${RED}✗${NC} Namespace $NAMESPACE not found"
    fi
done
echo ""

# Test 5: Check SSAP Pods
echo -e "${YELLOW}Test 5: Checking SSAP Pods${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-ssap"
    POD_COUNT=$(oc get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
    RUNNING_COUNT=$(oc get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    echo "  $NAMESPACE: $RUNNING_COUNT/$POD_COUNT pods running"

    # Show pod status details if any are not running
    if [ "$POD_COUNT" -ne "$RUNNING_COUNT" ]; then
        oc get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v "Running" || true
    fi
done
echo ""

# Test 6: Check SSAP Routes
echo -e "${YELLOW}Test 6: Checking SSAP Routes${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-ssap"
    ROUTE=$(oc get route -n $NAMESPACE -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "Not found")
    if [ "$ROUTE" != "Not found" ]; then
        echo -e "${GREEN}✓${NC} $NAMESPACE route: https://$ROUTE"
    else
        echo -e "${RED}✗${NC} $NAMESPACE route not found"
    fi
done
echo ""

# Test 7: Check Secrets
echo -e "${YELLOW}Test 7: Checking SSAP Secrets${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-ssap"

    if oc get secret secrets-rhaap-portal -n $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}✓${NC} $NAMESPACE: secrets-rhaap-portal exists"
    else
        echo -e "${RED}✗${NC} $NAMESPACE: secrets-rhaap-portal not found"
    fi

    if oc get secret secrets-scm -n $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}✓${NC} $NAMESPACE: secrets-scm exists"
    else
        echo -e "${RED}✗${NC} $NAMESPACE: secrets-scm not found"
    fi
done
echo ""

# Test 8: Check Helm Releases
echo -e "${YELLOW}Test 8: Checking Helm Releases${NC}"
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-ssap"
    HELM_RELEASE=$(helm list -n $NAMESPACE --short 2>/dev/null || echo "")
    if [ -n "$HELM_RELEASE" ]; then
        echo -e "${GREEN}✓${NC} $NAMESPACE: Helm release found: $HELM_RELEASE"
    else
        echo -e "${RED}✗${NC} $NAMESPACE: No Helm release found"
    fi
done
echo ""

# Test 9: Check OAuth Applications in AAP
echo -e "${YELLOW}Test 9: Checking OAuth Applications${NC}"
echo "NOTE: This requires AAP credentials. Checking via API..."
for i in $(seq 1 $NUM_USERS); do
    NAMESPACE="${NAMESPACE_PREFIX}${i}-aap-controller"
    ROUTE=$(oc get route -n $NAMESPACE -l app.kubernetes.io/component=automationcontroller -o jsonpath='{.items[0].spec.host}' 2>/dev/null)

    if [ -n "$ROUTE" ]; then
        # Try to ping the API (doesn't require auth)
        if curl -k -s -f "https://$ROUTE/api/v2/ping/" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $NAMESPACE: AAP API is accessible at https://$ROUTE"
        else
            echo -e "${YELLOW}⚠${NC} $NAMESPACE: AAP API not responding (may still be starting)"
        fi
    fi
done
echo ""

# Summary
echo "======================================"
echo -e "${YELLOW}Quick Status Summary${NC}"
echo "======================================"
echo ""

# Count successful components
AAP_NS_COUNT=0
SSAP_NS_COUNT=0
for i in $(seq 1 $NUM_USERS); do
    if oc get namespace "${NAMESPACE_PREFIX}${i}-aap-controller" &>/dev/null; then
        ((AAP_NS_COUNT++))
    fi
    if oc get namespace "${NAMESPACE_PREFIX}${i}-aap-ssap" &>/dev/null; then
        ((SSAP_NS_COUNT++))
    fi
done

echo "AAP Controller namespaces: $AAP_NS_COUNT/$NUM_USERS"
echo "SSAP namespaces: $SSAP_NS_COUNT/$NUM_USERS"
echo ""

# Show useful commands
echo "======================================"
echo "Useful Commands for Further Testing"
echo "======================================"
echo ""
echo "# Get all SSAP pods:"
echo "oc get pods -n user1-aap-ssap"
echo ""
echo "# Check SSAP logs:"
echo "oc logs -n user1-aap-ssap -l app.kubernetes.io/name=backstage"
echo ""
echo "# Get SSAP route URL:"
echo "echo \"https://\$(oc get route -n user1-aap-ssap -o jsonpath='{.items[0].spec.host}')\""
echo ""
echo "# Check AAP Controller route:"
echo "echo \"https://\$(oc get route -n user1-aap-controller -l app.kubernetes.io/component=automationcontroller -o jsonpath='{.items[0].spec.host}')\""
echo ""
echo "# View secret contents (base64 decoded):"
echo "oc get secret secrets-rhaap-portal -n user1-aap-ssap -o jsonpath='{.data.aap-host-url}' | base64 -d"
echo ""
