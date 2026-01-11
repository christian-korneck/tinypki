#!/bin/bash
# Generate Certificate Revocation List (CRL)
# This generates the CRL from OpenSSL's index.txt database

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

# Check if intermediate CA exists
if [[ ! -f "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" || ! -f "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" ]]; then
    echo "ERROR: Intermediate CA not found!"
    echo "Please run intermediate-ca/mkcert.sh first to generate the intermediate CA."
    exit 1
fi

cd "$SCRIPT_DIR"

# Initialize index.txt if it doesn't exist
if [[ ! -f "index.txt" ]]; then
    touch index.txt
fi

# Initialize CRL number if not exists
if [[ ! -f "crlnumber" ]]; then
    echo "01" > crlnumber
fi

echo "Generating CRL..."

# Generate CRL
openssl ca -config <(echo '[ ca ]
default_ca = CA_default

[ CA_default ]
database = index.txt
crlnumber = crlnumber
default_crl_days = 18250
default_md = sha384
crl_extensions = crl_ext

[ crl_ext ]
authorityKeyIdentifier = keyid:always') \
    -cert "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca.pem" \
    -keyfile "$INTERMEDIATE_CA_DIR/$PKI_NAME-intermediate-ca-key.pem" \
    -gencrl \
    -out "$PKI_NAME-intermediate.crl"

echo ""
echo "CRL generated successfully!"
echo ""
echo "CRL details:"
openssl crl -in "$PKI_NAME-intermediate.crl" -noout -text | head -20
echo ""
echo "File created:"
echo "  $PKI_NAME-intermediate.crl - CRL in PEM format"
echo ""
echo "Host these files at: $CRL_URL"
