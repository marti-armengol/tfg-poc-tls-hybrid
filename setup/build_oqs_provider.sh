#!/bin/bash
# Pas 2.3 - Compilació i instal·lació d'OQS-Provider
set -e

LIBOQS_PREFIX="$HOME/tfg-poc/liboqs-install"
BUILD_DIR="$HOME/tfg-poc/build/oqs-provider"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[1/5] Clonant oqs-provider..."
git clone --depth 1 https://github.com/open-quantum-safe/oqs-provider.git .

echo "[2/5] Configurant CMake..."
cmake -GNinja \
    -DCMAKE_PREFIX_PATH="$LIBOQS_PREFIX" \
    -DOPENSSL_ROOT_DIR=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -S . -B _build

echo "[3/5] Compilant..."
cmake --build _build --parallel $(nproc)

echo "[4/5] Instal·lant oqsprovider.so..."
sudo cmake --install _build --prefix /usr

echo "[5/5] Registrant liboqs.so al linker..."
echo "$LIBOQS_PREFIX/lib" | sudo tee /etc/ld.so.conf.d/liboqs.conf
sudo ldconfig

echo "✅ OQS-Provider instal·lat correctament"
ls /usr/lib/x86_64-linux-gnu/ossl-modules/ | grep oqs
