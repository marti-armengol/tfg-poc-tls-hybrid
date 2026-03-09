#!/bin/bash
# Pas 2.4 - Generació de certificats de test ECDSA P-256
set -e

CERTS_DIR="$HOME/tfg-poc/certs"
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

echo "[1/2] Generant clau privada ECDSA P-256..."
openssl ecparam -name prime256v1 -genkey -noout -out server.key

echo "[2/2] Generant certificat autosignat..."
openssl req -new -x509 \
    -key server.key \
    -out server.crt \
    -days 365 \
    -subj "/CN=localhost/O=TFG-PoC-UPF/C=ES" \
    -addext "subjectAltName=IP:127.0.0.1,DNS:localhost"

echo "✅ Certificats generats:"
openssl x509 -in server.crt -noout -text | \
    grep -E "Subject:|Issuer:|Not After|DNS|IP"
