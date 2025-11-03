#!/bin/bash
# Generate secrets for Ansible Semaphore deployment
# Usage: ./scripts/generate-secrets.sh

set -e

echo "=========================================="
echo "Semaphore Secrets Generator"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Generating database secrets...${NC}"
POSTGRES_ADMIN_PASSWORD=$(openssl rand -base64 32)
SEMAPHORE_DB_PASSWORD=$(openssl rand -base64 32)

echo -e "${BLUE}Generating Semaphore admin credentials...${NC}"
SEMAPHORE_ADMIN_PASSWORD=$(openssl rand -base64 32)

echo -e "${BLUE}Generating Semaphore encryption keys...${NC}"
SEMAPHORE_COOKIE_HASH=$(openssl rand -base64 32)
SEMAPHORE_COOKIE_ENCRYPTION=$(openssl rand -base64 32)
SEMAPHORE_ACCESS_KEY_ENCRYPTION=$(openssl rand -base64 32)

echo ""
echo -e "${GREEN}=========================================="
echo "Generated Secrets"
echo -e "==========================================${NC}"
echo ""

echo -e "${YELLOW}# Database Secrets${NC}"
echo "postgres_admin_password: \"$POSTGRES_ADMIN_PASSWORD\""
echo "semaphore_db_password: \"$SEMAPHORE_DB_PASSWORD\""
echo ""

echo -e "${YELLOW}# Semaphore Admin Credentials${NC}"
echo "semaphore_admin_password: \"$SEMAPHORE_ADMIN_PASSWORD\""
echo ""

echo -e "${YELLOW}# Semaphore Encryption Keys (base64-encoded)${NC}"
echo "semaphore_cookie_hash: \"$SEMAPHORE_COOKIE_HASH\""
echo "semaphore_cookie_encryption: \"$SEMAPHORE_COOKIE_ENCRYPTION\""
echo "semaphore_access_key_encryption: \"$SEMAPHORE_ACCESS_KEY_ENCRYPTION\""
echo ""

echo -e "${GREEN}=========================================="
echo "Instructions"
echo -e "==========================================${NC}"
echo ""
echo "1. Copy the secrets above to group_vars/all/secrets.yml"
echo "2. Keep the admin username and email as you prefer:"
echo "   - semaphore_admin_user: \"admin\""
echo "   - semaphore_admin_email: \"admin@example.com\""
echo "   - semaphore_admin_name: \"Administrator\""
echo ""
echo "3. Encrypt the secrets file with ansible-vault:"
echo "   ansible-vault encrypt group_vars/all/secrets.yml"
echo ""
echo "4. When running playbooks, use:"
echo "   ansible-playbook site.yml --ask-vault-pass"
echo ""
echo -e "${YELLOW}Note: All encryption keys are base64-encoded (32 bytes)${NC}"
echo -e "${YELLOW}      Generate new ones with: openssl rand -base64 32${NC}"
echo ""
