#!/bin/bash
# script to removes all generated certificates and keys
# WARNING: This will destory the PKI and delete all state!

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
if [[ ! -f "pki.conf" ]]; then
    echo "ERROR: pki.conf not found"
    exit 1
fi
source "pki.conf"

echo "=== PKI Force Clean ==="
echo ""
echo "WARNING: This will remove ALL certificates and keys!"
echo "All issued certificates will become INVALID!"
echo ""
read -p "Type 'yes' to confirm: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
# clean root ca
rm -f root-ca/$PKI_NAME-root-ca.pem root-ca/$PKI_NAME-root-ca-key.pem

# clean intermediate ca
rm -f intermediate-ca/$PKI_NAME-intermediate-ca.pem intermediate-ca/$PKI_NAME-intermediate-ca-key.pem

# clean server certs
rm -rf server/*/

# clean wildcard certs
rm -rf wildcard/*/

# clean crl
rm -f crl/$PKI_NAME-intermediate.crl
rm -f crl/index.txt crl/index.txt.old crl/index.txt.attr crl/index.txt.attr.old
rm -f crl/crlnumber crl/crlnumber.old

echo ""
echo "=== PKI Clean Complete ==="
echo "Run ./bootstrap.sh to create a new PKI."
