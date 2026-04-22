#!/bin/bash
# Generate secrets for Ansible Semaphore deployment
# Usage: ./scripts/generate-secrets.sh [--force]
#
# Creates group_vars/all/secrets.yml from secrets.yml.example with
# randomly generated passwords and encryption keys.

set -e

# Resolve paths relative to the script's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLE_FILE="$PROJECT_DIR/group_vars/all/secrets.yml.example"
SECRETS_FILE="$PROJECT_DIR/group_vars/all/secrets.yml"

# Colours for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

# Check for --force flag
FORCE=false
if [ "$1" = "--force" ]; then
    FORCE=true
fi

# Safety check: don't overwrite existing secrets
if [ -f "$SECRETS_FILE" ] && [ "$FORCE" = false ]; then
    echo -e "${RED}Error: $SECRETS_FILE already exists.${NC}"
    echo "Use --force to overwrite, or edit the existing file directly."
    exit 1
fi

# Check example file exists
if [ ! -f "$EXAMPLE_FILE" ]; then
    echo -e "${RED}Error: $EXAMPLE_FILE not found.${NC}"
    echo "Are you running this from the semaphore/ directory?"
    exit 1
fi

echo -e "${BLUE}Generating secrets for Semaphore deployment...${NC}"

# Generate random secrets
SEMAPHORE_DB_PASSWORD=$(openssl rand -base64 32)
SEMAPHORE_ADMIN_PASSWORD=$(openssl rand -base64 32)
SEMAPHORE_COOKIE_HASH=$(openssl rand -base64 32)
SEMAPHORE_COOKIE_ENCRYPTION=$(openssl rand -base64 32)
SEMAPHORE_ACCESS_KEY_ENCRYPTION=$(openssl rand -base64 32)

# Copy example and replace placeholders
cp "$EXAMPLE_FILE" "$SECRETS_FILE"

# Replace placeholder values with generated secrets
sed -i.bak \
    -e "s|semaphore_db_password: \"changeme_generate_with_openssl_rand_base64_32\"|semaphore_db_password: \"$SEMAPHORE_DB_PASSWORD\"|" \
    -e "s|semaphore_admin_password: \"changeme_generate_with_openssl_rand_base64_32\"|semaphore_admin_password: \"$SEMAPHORE_ADMIN_PASSWORD\"|" \
    -e "s|semaphore_cookie_hash: \"changeme_generate_with_openssl_rand_base64_32\"|semaphore_cookie_hash: \"$SEMAPHORE_COOKIE_HASH\"|" \
    -e "s|semaphore_cookie_encryption: \"changeme_generate_with_openssl_rand_base64_32\"|semaphore_cookie_encryption: \"$SEMAPHORE_COOKIE_ENCRYPTION\"|" \
    -e "s|semaphore_access_key_encryption: \"changeme_generate_with_openssl_rand_base64_32\"|semaphore_access_key_encryption: \"$SEMAPHORE_ACCESS_KEY_ENCRYPTION\"|" \
    "$SECRETS_FILE"

# Clean up sed backup file
rm -f "$SECRETS_FILE.bak"

echo ""
echo -e "${GREEN}=========================================="
echo " Secrets generated successfully!"
echo -e "==========================================${NC}"
echo ""
echo -e "  File: ${BLUE}$SECRETS_FILE${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review and customise the file (admin email, etc.):"
echo "     vim $SECRETS_FILE"
echo ""
echo "  2. Also review non-secret config in vars.yml:"
echo "     vim $PROJECT_DIR/group_vars/all/vars.yml"
echo ""
echo "  3. Encrypt the secrets file:"
echo "     ansible-vault encrypt $SECRETS_FILE"
echo ""
