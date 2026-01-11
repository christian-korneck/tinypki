#!/bin/bash
# Wildcard Certificate Revocation Script
# Usage: ./revoke.sh <wildcard_folder_name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRL_DIR="$SCRIPT_DIR/../crl"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <wildcard_folder_name>"
    echo "Example: $0 wildcard.example.com"
    exit 1
fi

CERT_NAME="$1"
CERT_FILE="$SCRIPT_DIR/$CERT_NAME/$CERT_NAME-cert-only.pem"

if [[ ! -f "$CERT_FILE" ]]; then
    echo "ERROR: Certificate not found: $CERT_FILE"
    exit 1
fi

"$CRL_DIR/revoke.sh" "$CERT_FILE"
