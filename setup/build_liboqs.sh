#!/bin/bash
# Pas 2.2 - Compilació de liboqs 0.15.0
set -e

INSTALL_PREFIX="$HOME/tfg-poc/liboqs-install"
BUILD_DIR="$HOME/tfg-poc/build/liboqs"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[1/4] Clonant liboqs..."
git clone --depth 1 https://github.com/open-quantum-safe/liboqs.git .

echo "[2/4] Configurant CMake..."
cmake -GNinja \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DBUILD_SHARED_LIBS=ON \
    -DOQS_DIST_BUILD=ON \
    -DOQS_USE_AVX2_INSTRUCTIONS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -S . -B _build

echo "[3/4] Compilant ($(nproc) cores)..."
cmake --build _build --parallel $(nproc)

echo "[4/4] Instal·lant a $INSTALL_PREFIX..."
cmake --install _build

echo "✅ liboqs instal·lat correctament"
ls "$INSTALL_PREFIX/lib/"
