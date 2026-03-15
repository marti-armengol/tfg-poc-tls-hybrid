#!/bin/bash
set -e

# =============================================================================
# TFG: Seguretat Post-Quàntica en TLS 1.3
# Atac A1 — Downgrade de Grup (§4.2.1)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$(cd "$SCRIPT_DIR/../../certs" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
OPENSSL_NOPQC_CNF="$SCRIPT_DIR/openssl-nopqc.cnf"

PORT_LEGACY=4434
PORT_STRICT=4435

SRV_LEGACY_PID=""
SRV_STRICT_PID=""

# =============================================================================
# FUNCIONS AUXILIARS
# =============================================================================

cleanup() {
    [ -n "$SRV_LEGACY_PID" ] && kill "$SRV_LEGACY_PID" 2>/dev/null && wait "$SRV_LEGACY_PID" 2>/dev/null || true
    [ -n "$SRV_STRICT_PID" ] && kill "$SRV_STRICT_PID" 2>/dev/null && wait "$SRV_STRICT_PID" 2>/dev/null || true
}
trap cleanup EXIT

save_result() {
    local file="$1"
    local content="$2"
    if [ -f "$file" ] && [ "${OVERWRITE:-0}" != "1" ]; then
        echo "  [SKIP] $file ja existeix. Usa --overwrite per sobreescriure."
    else
        echo "$content" > "$file"
        echo "  [SAVED] $file"
    fi
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================

for arg in "$@"; do
    case $arg in
        --overwrite) OVERWRITE=1 ;;
    esac
done

# =============================================================================
# VALIDACIONS PRÈVIES
# =============================================================================

print_header "A1 — Downgrade de Grup: Validació de l'entorn"

[ -f "$CERTS_DIR/server.crt" ] || { echo "ERROR: No trobat $CERTS_DIR/server.crt"; exit 1; }
[ -f "$CERTS_DIR/server.key" ] || { echo "ERROR: No trobat $CERTS_DIR/server.key"; exit 1; }
[ -f "$OPENSSL_NOPQC_CNF"  ] || { echo "ERROR: No trobat $OPENSSL_NOPQC_CNF"; exit 1; }

mkdir -p "$RESULTS_DIR"
echo "  CERTS_DIR : $CERTS_DIR"
echo "  RESULTS_DIR: $RESULTS_DIR"
echo "  CNF legacy : $OPENSSL_NOPQC_CNF"
echo "  Port legacy: $PORT_LEGACY | Port PQC estricte: $PORT_STRICT"

# =============================================================================
# ESCENARI A — DOWNGRADE SILENCIÓS
# =============================================================================

print_header "ESCENARI A — Downgrade Silenciós (Client PQC amb fallback → Servidor Legacy)"

echo "  Arrencant servidor LEGACY sense OQS-Provider al port $PORT_LEGACY..."
OPENSSL_CONF="$OPENSSL_NOPQC_CNF" openssl s_server \
    -cert "$CERTS_DIR/server.crt" \
    -key  "$CERTS_DIR/server.key" \
    -port "$PORT_LEGACY" \
    -tls1_3 \
    -groups "X25519:P-256" \
    -www -quiet \
    2>/dev/null &
SRV_LEGACY_PID=$!
sleep 1.5

echo "  Connectant client amb fallback (X25519MLKEM768:X25519:P-256)..."
OUTPUT_A=$(openssl s_client \
    -connect "localhost:$PORT_LEGACY" \
    -tls1_3 \
    -groups "X25519MLKEM768:X25519:P-256" \
    -provider oqsprovider \
    -provider default \
    -CAfile "$CERTS_DIR/server.crt" \
    -brief \
    2>&1 </dev/null || true)

echo ""
echo "$OUTPUT_A" | grep -E "Peer Temp Key|Negotiated|Verification|Protocol|Cipher" || true
echo ""

PEER_KEY=$(echo "$OUTPUT_A" | grep "Peer Temp Key" || true)
if echo "$PEER_KEY" | grep -q "X25519, 253 bits"; then
    echo "  ⚠️  DOWNGRADE SILENCIÓS: client PQC connectat sense protecció post-quàntica"
    echo "      El client oferia X25519MLKEM768 però ha negociat X25519 pur."
    echo "      Verification: OK — cap avís visible a l'usuari."
    echo "      Un adversari HNDL pot emmagatzemar aquest tràfic i aplicar Shor"
    echo "      sobre el key_share X25519 (32 bytes) per reconstruir K_ECDH."
else
    echo "  [INFO] Resultat obtingut: $PEER_KEY"
fi

save_result "$RESULTS_DIR/a1_scen_A_client.txt" "$OUTPUT_A"

kill "$SRV_LEGACY_PID" 2>/dev/null; wait "$SRV_LEGACY_PID" 2>/dev/null || true
SRV_LEGACY_PID=""

# =============================================================================
# ESCENARI B — CLIENT PQC-ONLY REBUTJAT
# =============================================================================

print_header "ESCENARI B — Client PQC-Only rebutjat per Servidor Legacy"

echo "  Arrencant servidor LEGACY de nou al port $PORT_LEGACY..."
OPENSSL_CONF="$OPENSSL_NOPQC_CNF" openssl s_server \
    -cert "$CERTS_DIR/server.crt" \
    -key  "$CERTS_DIR/server.key" \
    -port "$PORT_LEGACY" \
    -tls1_3 \
    -groups "X25519:P-256" \
    -www -quiet \
    2>/dev/null &
SRV_LEGACY_PID=$!
sleep 1.5

echo "  Connectant client PQC-only (X25519MLKEM768, sense fallback)..."
OUTPUT_B=$(openssl s_client \
    -connect "localhost:$PORT_LEGACY" \
    -tls1_3 \
    -groups "X25519MLKEM768" \
    -provider oqsprovider \
    -provider default \
    -CAfile "$CERTS_DIR/server.crt" \
    -brief \
    2>&1 </dev/null || true)

echo ""
echo "$OUTPUT_B" | grep -E "alert|failure|handshake|Negotiated|NULL" || true
echo ""

if echo "$OUTPUT_B" | grep -qiE "alert number 40|handshake failure|no shared group"; then
    echo "  ❌ CLIENT PQC-ONLY: no pot connectar a servidor legacy"
    echo "      SSL alert number 40 (handshake_failure): cap grup comú."
    echo "      Tensió clàssica: client estrictament PQC perd connectivitat,"
    echo "      cosa que en entorns reals genera pressió per reintroduir fallback"
    echo "      clàssic i, conseqüentment, la vulnerabilitat de l'Escenari A."
else
    echo "  [INFO] Resultat obtingut (revisar manualment):"
    echo "$OUTPUT_B" | head -5
fi

save_result "$RESULTS_DIR/a1_scen_B_client.txt" "$OUTPUT_B"

kill "$SRV_LEGACY_PID" 2>/dev/null; wait "$SRV_LEGACY_PID" 2>/dev/null || true
SRV_LEGACY_PID=""

# =============================================================================
# ESCENARI C — MITIGACIÓ: SERVIDOR PQC ESTRICTE
# =============================================================================

print_header "ESCENARI C — Mitigació: Servidor PQC Estricte rebutja Client Legacy"

echo "  Arrencant servidor PQC ESTRICTE (X25519MLKEM768 exclusiu) al port $PORT_STRICT..."
openssl s_server \
    -cert "$CERTS_DIR/server.crt" \
    -key  "$CERTS_DIR/server.key" \
    -port "$PORT_STRICT" \
    -tls1_3 \
    -groups "X25519MLKEM768" \
    -provider oqsprovider \
    -provider default \
    -www -quiet \
    2>/dev/null &
SRV_STRICT_PID=$!
sleep 1.5

echo "  Connectant client LEGACY (X25519 pur, sense oqsprovider)..."
OUTPUT_C=$(OPENSSL_CONF="$OPENSSL_NOPQC_CNF" openssl s_client \
    -connect "localhost:$PORT_STRICT" \
    -tls1_3 \
    -groups "X25519:P-256" \
    -provider default \
    -CAfile "$CERTS_DIR/server.crt" \
    -brief \
    2>&1 </dev/null || true)

echo ""
echo "$OUTPUT_C" | grep -E "alert|failure|shared group|Negotiated|NULL" || true
echo ""

if echo "$OUTPUT_C" | grep -qiE "no shared group|alert number 40|handshake failure"; then
    echo "  ✅ MITIGACIÓ EFECTIVA: servidor PQC estricte rebutja client sense ML-KEM"
    echo "      El servidor configurat amb -groups X25519MLKEM768 exclusiu"
    echo "      retorna handshake_failure a qualsevol client sense suport híbrid."
    echo "      Elimina completament el downgrade silenciós de l'Escenari A."
else
    echo "  [INFO] Resultat obtingut (revisar manualment):"
    echo "$OUTPUT_C" | head -5
fi

save_result "$RESULTS_DIR/a1_scen_C_client.txt" "$OUTPUT_C"

kill "$SRV_STRICT_PID" 2>/dev/null; wait "$SRV_STRICT_PID" 2>/dev/null || true
SRV_STRICT_PID=""

# =============================================================================
# TAULA RESUM
# =============================================================================

print_header "RESUM — Atac A1 Downgrade de Grup"

echo ""
echo "  ┌─────────────────────────────┬──────────────────────┬─────────────────────────┐"
echo "  │ Escenari                    │ Resultat             │ Risc TFG                │"
echo "  ├─────────────────────────────┼──────────────────────┼─────────────────────────┤"
echo "  │ A: Client fallback→Legacy   │ Downgrade silenciós  │ HNDL via Shor possible  │"
echo "  │ B: Client PQC-only→Legacy   │ Connexió rebutjada   │ Pèrdua de disponibilitat│"
echo "  │ C: Client legacy→PQC estric │ Connexió rebutjada   │ Mitigació efectiva ✅   │"
echo "  └─────────────────────────────┴──────────────────────┴─────────────────────────┘"
echo ""
echo "  CONCLUSIÓ (Cap. 4 §4.2.1):"
echo "  La condició C1 (negociació efectiva del grup híbrid) es viola quan el"
echo "  servidor no exigeix X25519MLKEM768. El downgrade és silenciós (Verification: OK)"
echo "  i un adversari HNDL pot emmagatzemar el tràfic degradat per desxifrar-lo"
echo "  en el futur amb un CRQC aplicant Shor sobre el key_share X25519 de 32 bytes."
echo "  La mitigació és la política estricta de grup al servidor (Escenari C)."
echo ""

