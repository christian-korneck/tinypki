#!/bin/bash
# Server Certificate Generator
# Usage: ./mkcert.sh <primary_name> [additional_san1] [additional_san2] ...
#
# This creates a folder named after the primary name containing:
#   - <name>.pem          - Server certificate with full chain
#   - <name>-key.pem      - Server private key
#   - <name>.pfx          - PKCS#12 bundle (for Windows/Java)
#   - <name>-cert-only.pem - Server certificate without chain

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
    echo "Usage: $0 <primary_name> [additional_san1] [additional_san2] ..."
    echo ""
    echo "Example:"
    echo "  $0 server.example.com server server2.example.com"
    exit 1
fi

PRIMARY_NAME="$1"
shift
ADDITIONAL_SANS=("$@")

# Check if intermediate CA exists
if [[ ! -f "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" || ! -f "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" ]]; then
    echo "ERROR: Intermediate CA not found!"
    echo "Please run intermediate-ca/mkcert.sh first to generate the intermediate CA."
    exit 1
fi

# Create output directory
OUTPUT_DIR="$SCRIPT_DIR/$PRIMARY_NAME"
if [[ -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: Certificate directory already exists: $OUTPUT_DIR"
    echo "Remove it first if you want to regenerate this certificate."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "Generating server certificate for: $PRIMARY_NAME"
if [[ ${#ADDITIONAL_SANS[@]} -gt 0 ]]; then
    echo "Additional SANs: ${ADDITIONAL_SANS[*]}"
fi

# Build hosts JSON array
HOSTS_JSON=$(printf '%s\n' "$PRIMARY_NAME" "${ADDITIONAL_SANS[@]}" | jq -R . | jq -s .)

# Patch intermediate CA config template in-memory
export VALIDITY_SERVER_CERTS
PATCHED_CONFIG=$(envsubst < "$INTERMEDIATE_CA_DIR/ca-config.json")
if [[ "${USE_CRL_URL:-false}" == "true" ]]; then
    PATCHED_CONFIG=$(echo "$PATCHED_CONFIG" | jq --arg crl "$CRL_URL" '.signing.profiles.server.crl_url = $crl')
fi

# Patch CSR template and generate certificate
export PRIMARY_NAME PKI_NAME HOSTS_JSON
envsubst < "$SCRIPT_DIR/csr.json" | cfssl gencert \
    -ca="$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" \
    -ca-key="$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" \
    -config=<(echo "$PATCHED_CONFIG") \
    -profile=server \
    - | cfssljson -bare "$PRIMARY_NAME"

# Create certificate with chain (server + intermediate, root should be in client trust stores)
cat "$PRIMARY_NAME.pem" "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" > "$PRIMARY_NAME-fullchain.pem"

# Keep the server-only cert
mv "$PRIMARY_NAME.pem" "$PRIMARY_NAME-cert-only.pem"

# The full chain is the main certificate file
mv "$PRIMARY_NAME-fullchain.pem" "$PRIMARY_NAME.pem"

# Create PKCS#12 bundle (PFX)
openssl pkcs12 -export \
    -out "$PRIMARY_NAME.pfx" \
    -inkey "$PRIMARY_NAME-key.pem" \
    -in "$PRIMARY_NAME.pem" \
    -passout "pass:$PFX_PASSWORD"

# Clean up
rm -f "$PRIMARY_NAME.csr"

# Set permissions
chmod 600 "$PRIMARY_NAME-key.pem" "$PRIMARY_NAME.pfx"
chmod 644 "$PRIMARY_NAME.pem" "$PRIMARY_NAME-cert-only.pem"

# Verify the certificate
echo ""
echo "Server certificate generated successfully!"
echo ""
echo "Certificate details:"
openssl x509 -in "$PRIMARY_NAME-cert-only.pem" -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null || \
openssl x509 -in "$PRIMARY_NAME-cert-only.pem" -noout -subject -issuer -dates

# Verify chain
echo ""
echo "Verifying certificate chain..."
openssl verify -CAfile "$ROOT_CA_DIR/$PKI_NAME-root-ca.pem" -untrusted "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" "$PRIMARY_NAME-cert-only.pem"

echo ""
echo "Files created in $OUTPUT_DIR:"
echo "  $PRIMARY_NAME.pem          - Server certificate with full chain (use this for web servers)"
echo "  $PRIMARY_NAME-key.pem      - Server private key"
echo "  $PRIMARY_NAME.pfx          - PKCS#12 bundle (password: $PFX_PASSWORD)"
echo "  $PRIMARY_NAME-cert-only.pem - Server certificate only (without chain)"
