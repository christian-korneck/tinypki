#!/bin/bash
# PKI Bootstrap Script
# Initializes the complete PKI infrastructure from scratch
# WARNING: Only run this once during initial PKI setup!

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
if [[ ! -f "pki.conf" ]]; then
    echo "ERROR: pki.conf not found"
    exit 1
fi
source "pki.conf"

echo "=== PKI Bootstrap for $PKI_NAME ==="
echo ""

# Check if PKI already exists
if [[ -f "root-ca/$PKI_NAME-root-ca.pem" || -f "intermediate-ca/$PKI_NAME-intermediate-ca.pem" ]]; then
    echo "ERROR: PKI already exists!"
    echo "If you want to start fresh, run ./force_clean.sh first."
    exit 1
fi

echo "Step 1/3: Generating Root CA..."
cd "$SCRIPT_DIR/root-ca" && ./mkcert.sh
echo ""

echo "Step 2/3: Generating Intermediate CA..."
cd "$SCRIPT_DIR/intermediate-ca" && ./mkcert.sh
echo ""

echo "Step 3/3: Generating initial CRL..."
cd "$SCRIPT_DIR/crl" && ./generate-crl.sh
echo ""

echo "=== PKI Bootstrap Complete ==="
echo ""
echo "Next steps:"
echo "  1. Distribute root-ca/$PKI_NAME-root-ca.pem to client trust stores"
if [[ "${USE_CRL_URL:-false}" == "true" ]]; then
    echo "  2. Host crl/$PKI_NAME-intermediate.crl at $CRL_URL"
else
    echo "  2. [NOT NEEDED AS CRL IS DISABLED] Host crl/$PKI_NAME-intermediate.crl at $CRL_URL"
fi
echo "  3. Generate server certs: cd server && ./mkcert.sh <hostname>"
echo "  4. Generate wildcard certs: cd wildcard && ./mkcert.sh <domain>"
