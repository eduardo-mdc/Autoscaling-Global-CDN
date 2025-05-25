#!/bin/bash
# Generate a proper self-signed certificate for testing

set -e

echo "Generating self-signed SSL certificate for HLS streaming..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Generate private key
openssl genrsa -out tls.key 2048

# Generate certificate
openssl req -new -x509 -key tls.key -out tls.crt -days 365 -subj "/C=US/ST=Test/L=Test/O=HLS-Streaming/CN=hls-streaming-server"

echo "Generated certificate files:"
echo "Private Key: $TEMP_DIR/tls.key"
echo "Certificate: $TEMP_DIR/tls.crt"

echo ""
echo "To update your SSL ConfigMap, use these files:"
echo ""
echo "--- Certificate (tls.crt) ---"
cat tls.crt
echo ""
echo "--- Private Key (tls.key) ---"
cat tls.key

echo ""
echo "Cleaning up temporary files..."
cd /
rm -rf "$TEMP_DIR"