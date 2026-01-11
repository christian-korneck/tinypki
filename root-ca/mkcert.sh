#!/bin/bash
# Root CA Certificate Generator
# This script generates the root CA certificate
# WARNING: Only run this once during initial PKI bootstrap!

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_ROOT="$SCRIPT_DIR/.."

# Load configuration
if [[ ! -f "$PKI_ROOT/pki.conf" ]]; then
    echo "ERROR: pki.conf not found in $PKI_ROOT"
    exit 1
fi
source "$PKI_ROOT/pki.conf"

cd "$SCRIPT_DIR"

# Check if root CA already exists
if [[ -f "$PKI_NAME-root-ca.pem" && -f "$PKI_NAME-root-ca-key.pem" ]]; then
    echo "ERROR: Root CA already exists!"
    echo "If you really want to regenerate it, manually remove $PKI_NAME-root-ca.pem and $PKI_NAME-root-ca-key.pem first."
    exit 1
fi

echo "Generating Root CA certificate for: $PKI_NAME"

# Patch CSR template and generate certificate
export PKI_NAME VALIDITY_ROOT_CA
envsubst < "$SCRIPT_DIR/csr.json" | cfssl gencert -initca - | cfssljson -bare "$PKI_NAME-root-ca"

# Verify the certificate
echo ""
echo "Root CA certificate generated successfully!"
echo ""
echo "Certificate details:"
openssl x509 -in "$PKI_NAME-root-ca.pem" -noout -subject -issuer -dates

# Clean up
rm -f "$PKI_NAME-root-ca.csr"

# Set restrictive permissions on the private key
chmod 600 "$PKI_NAME-root-ca-key.pem"
chmod 644 "$PKI_NAME-root-ca.pem"

echo ""
echo "Files created:"
echo "  $PKI_NAME-root-ca.pem       - Root CA certificate (distribute to clients)"
echo "  $PKI_NAME-root-ca-key.pem   - Root CA private key (KEEP SECURE!)"
