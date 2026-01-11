#!/bin/bash
# List Revoked Certificates
# Shows all certificates that have been revoked (from OpenSSL index.txt)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/index.txt" ]] || [[ ! -s "$SCRIPT_DIR/index.txt" ]]; then
    echo "No revoked certificates."
    exit 0
fi

# Check if there are any revoked entries (lines starting with R)
if ! grep -q "^R" "$SCRIPT_DIR/index.txt" 2>/dev/null; then
    echo "No revoked certificates."
    exit 0
fi

echo "Revoked Certificates:"
echo "====================="
echo ""
printf "%-20s %-16s %s\n" "SERIAL" "REVOCATION DATE" "SUBJECT"
printf "%-20s %-16s %s\n" "------" "---------------" "-------"

# OpenSSL index.txt format: STATUS\tEXPIRY\tREVOKE_DATE\tSERIAL\tFILENAME\tSUBJECT
while IFS=$'\t' read -r status expiry revoke_date serial filename subject; do
    # Only show revoked entries
    [[ "$status" != "R" ]] && continue

    # Format revoke_date from YYMMDDHHMMSSZ to readable format
    if [[ -n "$revoke_date" ]]; then
        formatted_date=$(echo "$revoke_date" | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)Z/20\1-\2-\3 \4:\5/')
    else
        formatted_date="unknown"
    fi

    printf "%-20s %-16s %s\n" "$serial" "$formatted_date" "$subject"
done < "$SCRIPT_DIR/index.txt"
