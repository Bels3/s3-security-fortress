#!/bin/bash
# ============================================================================
# S3 SECURITY FORTRESS - PRE-FLIGHT CHECKLIST
# Run this to verify your local environment is ready for deployment/demo.
# ============================================================================

set +e # Don't exit on error - we want the full report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

check_pass() { ((PASS_COUNT++)); echo -e "${GREEN}✅ PASS${NC}: $1"; }
check_fail() { ((FAIL_COUNT++)); echo -e "${RED}❌ FAIL${NC}: $1"; }
check_warn() { ((WARN_COUNT++)); echo -e "${YELLOW}⚠️  WARN${NC}: $1"; }

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         🏰 S3 SECURITY FORTRESS - PRE-FLIGHT CHECK         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# PHASE 1: Toolchain Validation
# ============================================================================
echo -e "${CYAN}━━━ PHASE 1: Essential Tools ━━━${NC}"

# Check Terraform
if command -v terraform &> /dev/null; then
    check_pass "Terraform installed ($(terraform version | head -n 1))"
else
    check_fail "Terraform not found"
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    check_pass "AWS CLI installed"
else
    check_fail "AWS CLI not found"
fi

# Check Conftest (for OPA)
if command -v conftest &> /dev/null; then
    check_pass "Conftest installed (OPA validation ready)"
else
    check_warn "Conftest not found - OPA checks will be skipped"
fi

# Check jq
if command -v jq &> /dev/null; then
    check_pass "jq installed"
else
    check_fail "jq not found (required for parsing results)"
fi

echo ""

# ============================================================================
# PHASE 2: Project Integrity
# ============================================================================
echo -e "${CYAN}━━━ PHASE 2: Project Files ━━━${NC}"

# Check Security Policy
if [[ -f "$PROJECT_ROOT/policy/s3_guardrails.rego" ]]; then
    check_pass "OPA Guardrails present"
else
    check_fail "OPA Policy missing in /policy"
fi

# Check Validation Script
if [[ -x "$SCRIPT_DIR/fortress-validate.sh" ]]; then
    check_pass "Validation script exists and is executable"
else
    check_fail "Validation script missing or needs chmod +x"
fi

# Check Integration Module
if [[ -d "$PROJECT_ROOT/terraform/examples/complete-integration" ]]; then
    check_pass "Complete Integration module found"
else
    check_fail "Integration module missing"
fi

echo ""

# ============================================================================
# PHASE 3: Cloud Connectivity
# ============================================================================
echo -e "${CYAN}━━━ PHASE 3: AWS Connectivity ━━━${NC}"

if aws sts get-caller-identity &> /dev/null; then
    USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
    check_pass "Authenticated as: $USER_ARN"
else
    check_fail "Not authenticated to AWS. Run 'aws configure'"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  SUMMARY: ${GREEN}$PASS_COUNT Passed${NC} | ${RED}$FAIL_COUNT Failed${NC} | ${YELLOW}$WARN_COUNT Warnings${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}🚀 FORTRESS IS READY FOR DEPLOYMENT!${NC}"
else
    echo -e "${RED}🛑 FIX FAILURES BEFORE PROCEEDING${NC}"
fi
echo ""
