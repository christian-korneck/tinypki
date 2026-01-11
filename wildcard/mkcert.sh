#!/bin/bash
# Wildcard Certificate Generator
# Usage: ./mkcert.sh <domain>
#
# Example: ./mkcert.sh example.com       -> *.example.com
#          ./mkcert.sh sub.example.com   -> *.sub.example.com
#
# This creates a folder containing:
#   - wildcard.<domain>.pem          - Wildcard certificate with full chain
#   - wildcard.<domain>-key.pem      - Wildcard private key
#   - wildcard.<domain>.pfx          - PKCS#12 bundle (for Windows/Java)
#   - wildcard.<domain>-cert-only.pem - Wildcard certificate without chain

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_ROOT="$SCRIPT_DIR/.."
INTERMEDIATE_CA_DIR="$PKI_ROOT/intermediate-ca"
ROOT_CA_DIR="$PKI_ROOT/root-ca"

# Load configuration
if [[ ! -f "$PKI_ROOT/pki.conf" ]]; then
    echo "ERROR: pki.conf not found in $PKI_ROOT"
    exit 1
fi
source "$PKI_ROOT/pki.conf"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domain>"
    echo ""
    echo "Example:"
    echo "  $0 example.com       -> *.example.com"
    echo "  $0 sub.example.com   -> *.sub.example.com"
    exit 1
fi

WILDCARD_DOMAIN="$1"
WILDCARD_CN="*.$WILDCARD_DOMAIN"
FILE_PREFIX="wildcard.$WILDCARD_DOMAIN"
OUTPUT_DIR="$SCRIPT_DIR/$FILE_PREFIX"

# Check if intermediate CA exists
if [[ ! -f "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" || ! -f "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" ]]; then
    echo "ERROR: Intermediate CA not found!"
    echo "Please run intermediate-ca/mkcert.sh first to generate the intermediate CA."
    exit 1
fi

# Create output directory
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: Certificate directory already exists: $OUTPUT_DIR"
    echo "Remove it first if you want to regenerate this certificate."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "Generating wildcard certificate for: $WILDCARD_CN"
echo "Also valid for: $WILDCARD_DOMAIN"

# Build hosts JSON array
HOSTS_JSON=$(printf '%s\n' "$WILDCARD_CN" "$WILDCARD_DOMAIN" | jq -R . | jq -s .)

# Patch intermediate CA config template in-memory
# Export as VALIDITY_SERVER_CERTS since that's what ca-config.json uses
export VALIDITY_SERVER_CERTS="$VALIDITY_WILDCARD_CERTS"
PATCHED_CONFIG=$(envsubst < "$INTERMEDIATE_CA_DIR/ca-config.json")
if [[ "${USE_CRL_URL:-false}" == "true" ]]; then
    PATCHED_CONFIG=$(echo "$PATCHED_CONFIG" | jq --arg crl "$CRL_URL" '.signing.profiles.server.crl_url = $crl')
fi

# Patch CSR template and generate certificate
export WILDCARD_CN PKI_NAME HOSTS_JSON
envsubst < "$SCRIPT_DIR/csr.json" | cfssl gencert \
    -ca="$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" \
    -ca-key="$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" \
    -config=<(echo "$PATCHED_CONFIG") \
    -profile=server \
    - | cfssljson -bare "$FILE_PREFIX"

# Create certificate with chain (wildcard + intermediate, root should be in client trust stores)
cat "$FILE_PREFIX.pem" "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" > "$FILE_PREFIX-fullchain.pem"

# Keep the wildcard-only cert
mv "$FILE_PREFIX.pem" "$FILE_PREFIX-cert-only.pem"

# The full chain is the main certificate file
mv "$FILE_PREFIX-fullchain.pem" "$FILE_PREFIX.pem"

# Create PKCS#12 bundle (PFX)
openssl pkcs12 -export \
    -out "$FILE_PREFIX.pfx" \
    -inkey "$FILE_PREFIX-key.pem" \
    -in "$FILE_PREFIX.pem" \
    -passout "pass:$PFX_PASSWORD"

# Clean up
rm -f "$FILE_PREFIX.csr"

# Set permissions
chmod 600 "$FILE_PREFIX-key.pem" "$FILE_PREFIX.pfx"
chmod 644 "$FILE_PREFIX.pem" "$FILE_PREFIX-cert-only.pem"

# Verify the certificate
echo ""
echo "Wildcard certificate generated successfully!"
echo ""
echo "Certificate details:"
openssl x509 -in "$FILE_PREFIX-cert-only.pem" -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null || \
openssl x509 -in "$FILE_PREFIX-cert-only.pem" -noout -subject -issuer -dates

# Verify chain
echo ""
echo "Verifying certificate chain..."
openssl verify -CAfile "$ROOT_CA_DIR/$PKI_NAME-root-ca.pem" -untrusted "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" "$FILE_PREFIX-cert-only.pem"

echo ""
echo "Files created in $OUTPUT_DIR:"
echo "  $FILE_PREFIX.pem          - Wildcard certificate with full chain (use this for web servers)"
echo "  $FILE_PREFIX-key.pem      - Wildcard private key"
echo "  $FILE_PREFIX.pfx          - PKCS#12 bundle (password: $PFX_PASSWORD)"
echo "  $FILE_PREFIX-cert-only.pem - Wildcard certificate only (without chain)"
