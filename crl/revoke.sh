#!/bin/bash
# Revoke Certificate
# Usage: ./revoke.sh <certificate_file>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_ROOT="$SCRIPT_DIR/.."
INTERMEDIATE_CA_DIR="$PKI_ROOT/intermediate-ca"

# Load configuration
if [[ ! -f "$PKI_ROOT/pki.conf" ]]; then
    echo "ERROR: pki.conf not found in $PKI_ROOT"
    exit 1
fi
source "$PKI_ROOT/pki.conf"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <certificate_file>"
    exit 1
fi

CERT_FILE="$1"

if [[ ! -f "$CERT_FILE" ]]; then
    echo "ERROR: Certificate file not found: $CERT_FILE"
    exit 1
fi

cd "$SCRIPT_DIR"

# Initialize index.txt if it doesn't exist
if [[ ! -f "index.txt" ]]; then
    touch index.txt
fi

# Get certificate serial for duplicate check
SERIAL=$(openssl x509 -in "$CERT_FILE" -noout -serial | cut -d= -f2)

# Check if already revoked
if grep -q "	$SERIAL	" "index.txt" 2>/dev/null; then
    echo "WARNING: Certificate with serial $SERIAL is already revoked"
    exit 0
fi

# Revoke the certificate using OpenSSL
echo "Revoking certificate..."
openssl ca -config <(echo '[ ca ]
default_ca = CA_default

[ CA_default ]
database = index.txt
default_md = sha384') \
    -cert "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" \
    -keyfile "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" \
    -revoke "$CERT_FILE"

CN=$(openssl x509 -in "$CERT_FILE" -noout -subject | sed -n 's/.*CN *= *\([^,]*\).*/\1/p')
echo ""
echo "Added to revocation database:"
echo "  Serial: $SERIAL"
echo "  CN: $CN"

# Regenerate CRL
"$SCRIPT_DIR/generate-crl.sh"
