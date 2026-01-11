#!/bin/bash
# Server Certificate Revocation Script
# Usage: ./revoke.sh <certificate_name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRL_DIR="$SCRIPT_DIR/../crl"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <certificate_name>"
    echo "Example: $0 server.example.com"
    exit 1
fi

CERT_NAME="$1"
CERT_FILE="$SCRIPT_DIR/$CERT_NAME/$CERT_NAME-cert-only.pem"

if [[ ! -f "$CERT_FILE" ]]; then
    echo "ERROR: Certificate not found: $CERT_FILE"
    exit 1
fi

"$CRL_DIR/revoke.sh" "$CERT_FILE"
