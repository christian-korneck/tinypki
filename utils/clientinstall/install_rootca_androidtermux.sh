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

echo "Installing prereqs..."
pkg install -y openssl-tool

echo "Installing CA certificate..."
add-trusted-certificate "$PEM"

echo "Done."
