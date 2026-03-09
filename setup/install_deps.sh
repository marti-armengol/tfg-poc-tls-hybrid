#!/bin/bash
# Pas 2.1 - Instal·lació de dependències
set -e

echo "[1/2] Actualitzant repositoris..."
sudo apt update

echo "[2/2] Instal·lant dependències..."
sudo apt install -y \
    git \
    libssl-dev \
    wireshark \
    tcpdump \
    python3-pytest \
    python3-pytest-xdist \
    unzip

echo "✅ Dependències instal·lades correctament"
openssl version
