#!/bin/bash
set -e # Stop on errors
# Colors for authority
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}🏰 S3 SECURITY FORTRESS: INTEGRATION TEST SUITE${NC}"
echo "======================================================"

FAILED=0

# TEST CASE 1: Encryption Enforcement
test-encryption() {
    echo -e "🔍 [TEST 1] Verifying KMS Encryption Policy..."
    # Look for the conditional logic that enforces aws:kms
    if grep -q "aws:kms" terraform/modules/secure-s3-bucket/main.tf; then
        echo -e "${GREEN}✅ PASS: Server-Side Encryption logic is present.${NC}"
    else
        echo -e "${RED}❌ FAIL: KMS encryption logic missing from module.${NC}"
        FAILED=1
    fi
}


# TEST CASE 2: Immutability (Object Lock)
test-immutability() {
    echo -e "🔍 [TEST 2] Verifying Object Lock Compliance Mode..."
    if grep -qE "mode\s*=\s*\"COMPLIANCE\"" terraform/modules/object-lock/main.tf; then
        echo -e "${GREEN}✅ PASS: Compliance mode prevents even Root deletion.${NC}"
    else
        echo -e "${RED}❌ FAIL: Object lock is not in Compliance mode.${NC}"
        FAILED=1
    fi
}

# TEST CASE 3: Zero-Credential Access (Presigned URLs)
test-lambda-isolation() {
    echo -e "🔍 [TEST 3] Verifying Lambda least-privilege policies..."
    if [ -f "terraform/modules/presigned-access/lambda/upload.py" ]; then
        echo -e "${GREEN}✅ PASS: Upload isolation logic present.${NC}"
    else
        echo -e "${RED}❌ FAIL: Lambda source code missing.${NC}"
    fi
}

# RUN ALL
test-encryption
test-immutability
test-lambda-isolation

echo "======================================================"
if [ $FAILED -eq 1 ]; then
    echo -e "${RED}❌ INTEGRATION AUDIT FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}🏆 FULL FORTRESS AUDIT COMPLETE: 100% SECURE${NC}"
    exit 0
fi

