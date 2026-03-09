#!/bin/bash
# Pas 2.6 - Client TLS 1.3 amb X25519MLKEM768
# Executa en Terminal 2 mentre el servidor està actiu

CERTS_DIR="$HOME/tfg-poc/certs"

echo "🔌 Connectant a localhost:4433 amb X25519MLKEM768..."
echo ""

openssl s_client \
    -connect localhost:4433 \
    -tls1_3 \
    -groups X25519MLKEM768 \
    -provider oqsprovider \
    -provider default \
    -CAfile "$CERTS_DIR/server.crt" \
    -brief

echo ""
echo "✅ Cerca 'Negotiated TLS1.3 group: X25519MLKEM768' a l'output"
