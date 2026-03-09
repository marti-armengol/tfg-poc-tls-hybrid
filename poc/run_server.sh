#!/bin/bash
# Pas 2.5 - Servidor TLS 1.3 amb X25519MLKEM768
# Executa en Terminal 1 i deixa corrent

CERTS_DIR="$HOME/tfg-poc/certs"

echo "🚀 Iniciant servidor TLS 1.3 X25519MLKEM768 al port 4433..."
echo "   Atura amb Ctrl+C"
echo ""

openssl s_server \
    -cert "$CERTS_DIR/server.crt" \
    -key  "$CERTS_DIR/server.key" \
    -port 4433 \
    -tls1_3 \
    -groups X25519MLKEM768 \
    -provider oqsprovider \
    -provider default \
    -www
