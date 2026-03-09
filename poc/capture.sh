#!/bin/bash
# Pas 2.7 - Captura tcpdump del handshake TLS
# Executa en Terminal 3 ABANS del client

CAPTURES_DIR="$HOME/tfg-poc/captures"
mkdir -p "$CAPTURES_DIR"

FILENAME="poc_tls_hybrid_$(date +%Y%m%d_%H%M%S).pcap"

echo "📡 Capturant tràfic al port 4433 (loopback)..."
echo "   Fitxer: $CAPTURES_DIR/$FILENAME"
echo "   Atura amb Ctrl+C un cop el client hagi connectat"
echo ""

sudo tcpdump -i lo -w "$CAPTURES_DIR/$FILENAME" port 4433

echo ""
echo "✅ Captura guardada: $CAPTURES_DIR/$FILENAME"
echo "   Obre amb: wireshark $CAPTURES_DIR/$FILENAME"
