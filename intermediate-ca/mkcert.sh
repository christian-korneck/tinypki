#!/bin/bash
# Intermediate CA Certificate Generator
# This script generates an intermediate CA certificate signed by the root CA
# WARNING: Only run this once during initial PKI bootstrap or to create additional intermediate CAs!

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_ROOT="$SCRIPT_DIR/.."
ROOT_CA_DIR="$PKI_ROOT/root-ca"

# Load configuration
if [[ ! -f "$PKI_ROOT/pki.conf" ]]; then
    echo "ERROR: pki.conf not found in $PKI_ROOT"
    exit 1
fi
source "$PKI_ROOT/pki.conf"

cd "$SCRIPT_DIR"

# Check if root CA exists
if [[ ! -f "$ROOT_CA_DIR/$PKI_NAME-root-ca.pem" || ! -f "$ROOT_CA_DIR/$PKI_NAME-root-ca-key.pem" ]]; then
    echo "ERROR: Root CA not found!"
    echo "Please run root-ca/mkcert.sh first to generate the root CA."
    exit 1
fi

# Check if intermediate CA already exists
if [[ -f "$PKI_NAME-intermediate-ca.pem" && -f "$PKI_NAME-intermediate-ca-key.pem" ]]; then
    echo "ERROR: Intermediate CA already exists!"
    echo "If you really want to regenerate it, manually remove $PKI_NAME-intermediate-ca.pem and $PKI_NAME-intermediate-ca-key.pem first."
    echo "WARNING: This will invalidate ALL certificates issued by this intermediate CA!"
    exit 1
fi

echo "Generating Intermediate CA certificate for: $PKI_NAME"

# Patch CSR template and generate intermediate CA key and CSR
export PKI_NAME VALIDITY_INTERMEDIATE_CA
envsubst < "$SCRIPT_DIR/csr.json" | cfssl gencert -initca - | cfssljson -bare "$PKI_NAME-intermediate-ca"

# Patch root CA config template in-memory and sign the intermediate CA
envsubst < "$ROOT_CA_DIR/ca-config.json" | cfssl sign \
    -ca "$ROOT_CA_DIR/$PKI_NAME-root-ca.pem" \
    -ca-key "$ROOT_CA_DIR/$PKI_NAME-root-ca-key.pem" \
    -config /dev/stdin \
    -profile intermediate \
    "$PKI_NAME-intermediate-ca.csr" | cfssljson -bare "$PKI_NAME-intermediate-ca"

# Verify the certificate
echo ""
echo "Intermediate CA certificate generated successfully!"
echo ""
echo "Certificate details:"
openssl x509 -in "$PKI_NAME-intermediate-ca.pem" -noout -subject -issuer -dates

# Verify chain
echo ""
echo "Verifying certificate chain..."
openssl verify -CAfile "$ROOT_CA_DIR/$PKI_NAME-root-ca.pem" "$PKI_NAME-intermediate-ca.pem"

# Clean up
rm -f "$PKI_NAME-intermediate-ca.csr"

# Set restrictive permissions on the private key
chmod 600 "$PKI_NAME-intermediate-ca-key.pem"
chmod 644 "$PKI_NAME-intermediate-ca.pem"

echo ""
echo "Files created:"
echo "  $PKI_NAME-intermediate-ca.pem       - Intermediate CA certificate"
echo "  $PKI_NAME-intermediate-ca-key.pem   - Intermediate CA private key (KEEP SECURE!)"
