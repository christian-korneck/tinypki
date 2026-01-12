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

echo "Installing CA certificate..."
sudo cp "$PEM" /etc/pki/ca-trust/source/anchors/

echo "Updating trust store..."
sudo update-ca-trust

echo "Done."
