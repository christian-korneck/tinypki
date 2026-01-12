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

# 1. Keychain (browsers, Safari, apps using Security framework)
echo "Adding to System keychain..."
sudo security add-trusted-cert -d -r trustRoot -p ssl -k /Library/Keychains/System.keychain "$PEM"

# 2. System CA bundle (curl, LibreSSL, OpenSSL tools)
echo "Adding to /etc/ssl/cert.pem..."
cat "$PEM" | sudo tee -a /etc/ssl/cert.pem > /dev/null

# 3. Homebrew CA bundle (if installed)
if command -v brew &>/dev/null; then
  BREW_CA="$(brew --prefix)/etc/ca-certificates/cert.pem"
  if [ -f "$BREW_CA" ]; then
    echo "Adding to Homebrew CA bundle..."
    cat "$PEM" | sudo tee -a "$BREW_CA" > /dev/null
  fi
fi

# 4. Backup copy for re-adding after OS updates
echo "Saving backup to /usr/local/share/ca-certificates/..."
sudo mkdir -p /usr/local/share/ca-certificates
sudo cp "$PEM" /usr/local/share/ca-certificates/

echo "Done."
