#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/ca.pem"
  exit 1
fi

PEM="$1"

if [ ! -f "$PEM" ]; then
  echo "Error: File not found: $PEM"
  exit 1
fi

CERTNAME="$(basename "$PEM" .pem).crt"

echo "Installing CA certificate..."
sudo cp "$PEM" "/usr/local/share/ca-certificates/$CERTNAME"

echo "Updating trust store..."
sudo update-ca-certificates

echo "Done."
