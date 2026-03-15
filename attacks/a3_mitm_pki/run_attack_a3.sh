#!/bin/bash
set -e

# =============================================================================
# TFG: Seguretat Post-Quàntica en TLS 1.3
# Atac A3 — MitM sobre PKI Clàssica (§4.2.3 + §4.3.1)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$(cd "$SCRIPT_DIR/../../certs" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

PORT_LEGIT=4437
PORT_ROUGE=4438
PORT_NAIVE=4439

SRV_LEGIT_PID=""
SRV_ROUGE_PID=""
SRV_NAIVE_PID=""

# =============================================================================
# FUNCIONS AUXILIARS
# =============================================================================

cleanup() {
    [ -n "$SRV_LEGIT_PID" ] && kill "$SRV_LEGIT_PID" 2>/dev/null && wait "$SRV_LEGIT_PID" 2>/dev/null || true
    [ -n "$SRV_ROUGE_PID" ] && kill "$SRV_ROUGE_PID" 2>/dev/null && wait "$SRV_ROUGE_PID" 2>/dev/null || true
    [ -n "$SRV_NAIVE_PID" ] && kill "$SRV_NAIVE_PID" 2>/dev/null && wait "$SRV_NAIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

save_result() {
    local file="$1"
    local content="$2"
    if [ -f "$file" ] && [ "${OVERWRITE:-0}" != "1" ]; then
        echo "  [SKIP] $(basename $file) ja existeix. Usa --overwrite per sobreescriure."
    else
        printf '%s\n' "$content" > "$file"
        echo "  [SAVED] $(basename $file)"
    fi
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

run_client() {
    local port="$1"
    local cafile="$2"
    openssl s_client \
        -connect "localhost:$port" \
        -tls1_3 \
        -groups "X25519MLKEM768" \
        -provider oqsprovider \
        -provider default \
        -CAfile "$cafile" \
        -keylogfile "$RESULTS_DIR/tls_keys_a3.log" \
        -brief \
        2>&1 </dev/null || true
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

print_header "A3 — MitM sobre PKI Clàssica: Validació de l'entorn"

[ -f "$CERTS_DIR/server.crt" ] || { echo "ERROR: No trobat $CERTS_DIR/server.crt"; exit 1; }
[ -f "$CERTS_DIR/server.key" ] || { echo "ERROR: No trobat $CERTS_DIR/server.key"; exit 1; }

mkdir -p "$RESULTS_DIR"
echo "  CERTS_DIR  : $CERTS_DIR"
echo "  RESULTS_DIR: $RESULTS_DIR"
echo "  Ports      : legítim=$PORT_LEGIT, rogue=$PORT_ROUGE, naïf=$PORT_NAIVE"

# =============================================================================
# CONFIGURACIÓ INICIAL: GENERACIÓ DE CERTIFICATS DE L'ADVERSARI
# =============================================================================

print_header "Configuració inicial: Certificats de l'adversari"

# stolen.key: simula l'output de l'algorisme de Shor sobre la clau pública ECDSA
if [ ! -f "$RESULTS_DIR/stolen.key" ] || [ "${OVERWRITE:-0}" = "1" ]; then
    cp "$CERTS_DIR/server.key" "$RESULTS_DIR/stolen.key"
    echo "  [CREATED] stolen.key — simula clau privada obtinguda per Shor sobre ECDSA P-256"
else
    echo "  [SKIP] stolen.key ja existeix."
fi

# attacker_naive: certificat propi de l'adversari (sense Shor, clau diferent)
if [ ! -f "$RESULTS_DIR/attacker_naive.key" ] || [ "${OVERWRITE:-0}" = "1" ]; then
    openssl ecparam -name prime256v1 -genkey -noout \
        -out "$RESULTS_DIR/attacker_naive.key" 2>/dev/null
    echo "  [CREATED] attacker_naive.key"
else
    echo "  [SKIP] attacker_naive.key ja existeix."
fi

if [ ! -f "$RESULTS_DIR/attacker_naive.crt" ] || [ "${OVERWRITE:-0}" = "1" ]; then
    openssl req -new -x509 \
        -key "$RESULTS_DIR/attacker_naive.key" \
        -out "$RESULTS_DIR/attacker_naive.crt" \
        -days 365 \
        -subj "/CN=localhost/O=ADVERSARI-TFG/C=ES" \
        -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" \
        2>/dev/null
    echo "  [CREATED] attacker_naive.crt (O=ADVERSARI-TFG)"
else
    echo "  [SKIP] attacker_naive.crt ja existeix."
fi

echo ""
echo "  Fingerprints (han de ser DIFERENTS entre si):"
echo "  Legítim : $(openssl x509 -in $CERTS_DIR/server.crt -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)"
echo "  Naïf    : $(openssl x509 -in $RESULTS_DIR/attacker_naive.crt -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)"

# Inicialitza keylog net si --overwrite
[ "${OVERWRITE:-0}" = "1" ] && rm -f "$RESULTS_DIR/tls_keys_a3.log"

# =============================================================================
# ESCENARI 1 — SERVIDOR LEGÍTIM (BASELINE)
# =============================================================================

print_header "ESCENARI 1 — Servidor Legítim (referència baseline)"

echo "  Arrencant servidor LEGÍTIM (server.crt + server.key) al port $PORT_LEGIT..."
openssl s_server \
    -cert "$CERTS_DIR/server.crt" \
    -key  "$CERTS_DIR/server.key" \
    -port "$PORT_LEGIT" \
    -tls1_3 \
    -groups "X25519MLKEM768" \
    -provider oqsprovider \
    -provider default \
    -www -quiet \
    2>/dev/null &
SRV_LEGIT_PID=$!
sleep 1.5

OUTPUT_1=$(run_client "$PORT_LEGIT" "$CERTS_DIR/server.crt")

echo ""
echo "$OUTPUT_1" | grep -E "Peer signature|Negotiated|Verification" || true
echo ""

VERIF_1=$(echo "$OUTPUT_1" | grep "Verification" || echo "Verification: (no trobat)")
if echo "$VERIF_1" | grep -q "OK"; then
    echo "  ✅ SERVIDOR LEGÍTIM: Verification: OK"
    echo "     Peer signature: ecdsa_secp256r1_sha256 (ECDSA P-256)"
    echo "     Grup negociat: X25519MLKEM768"
fi

save_result "$RESULTS_DIR/a3_1_legit.txt" "$OUTPUT_1"

kill "$SRV_LEGIT_PID" 2>/dev/null; wait "$SRV_LEGIT_PID" 2>/dev/null || true
SRV_LEGIT_PID=""

# =============================================================================
# ESCENARI 2 — SERVIDOR ROGUE (CLAU ROBADA VIA SHOR SIMULAT)
# =============================================================================

print_header "ESCENARI 2 — Servidor Rogue (clau robada via Shor simulat)"

echo "  Context: l'adversari aplica l'algorisme de Shor sobre la clau pública ECDSA"
echo "  P-256 del certificat del servidor (accessible públicament), obtenint sk_ECDSA."
echo "  Configura un servidor rogue amb el CERTIFICAT ORIGINAL + CLAU ROBADA."
echo ""
echo "  Arrencant servidor ROGUE (server.crt + stolen.key) al port $PORT_ROUGE..."
openssl s_server \
    -cert "$CERTS_DIR/server.crt" \
    -key  "$RESULTS_DIR/stolen.key" \
    -port "$PORT_ROUGE" \
    -tls1_3 \
    -groups "X25519MLKEM768" \
    -provider oqsprovider \
    -provider default \
    -www -quiet \
    2>/dev/null &
SRV_ROUGE_PID=$!
sleep 1.5

OUTPUT_2=$(run_client "$PORT_ROUGE" "$CERTS_DIR/server.crt")

echo ""
echo "$OUTPUT_2" | grep -E "Peer signature|Negotiated|Verification" || true
echo ""

VERIF_2=$(echo "$OUTPUT_2" | grep "Verification" || echo "Verification: (no trobat)")
if echo "$VERIF_2" | grep -q "OK"; then
    echo "  ⚠️  SERVIDOR ROGUE: Verification: OK — CLIENT NO POT DISTINGIR"
    echo "     L'adversari usa el certificat legítim original amb la clau robada."
    echo "     CertificateVerify és vàlid perquè stolen.key = server.key (Shor)."
    echo "     El client veu exactament el mateix que en l'Escenari 1."
    echo "     Canal negociat: X25519MLKEM768 — confidencialment post-quàntic"
    echo "     però autenticació completament compromesa."
fi

save_result "$RESULTS_DIR/a3_2_rogue.txt" "$OUTPUT_2"

kill "$SRV_ROUGE_PID" 2>/dev/null; wait "$SRV_ROUGE_PID" 2>/dev/null || true
SRV_ROUGE_PID=""

# =============================================================================
# ESCENARI 3 — ADVERSARI NAÏF (CERTIFICAT PROPI, SENSE SHOR)
# =============================================================================

print_header "ESCENARI 3 — Adversari Naïf (certificat propi, sense Shor)"

echo "  Context: adversari sense CRQC genera el seu propi certificat auto-signat"
echo "  amb CN=localhost però clau privada diferent. La PKI del client el detecta."
echo ""
echo "  Arrencant servidor NAÏF (attacker_naive.crt + attacker_naive.key) al port $PORT_NAIVE..."
openssl s_server \
    -cert "$RESULTS_DIR/attacker_naive.crt" \
    -key  "$RESULTS_DIR/attacker_naive.key" \
    -port "$PORT_NAIVE" \
    -tls1_3 \
    -groups "X25519MLKEM768" \
    -provider oqsprovider \
    -provider default \
    -www -quiet \
    2>/dev/null &
SRV_NAIVE_PID=$!
sleep 1.5

OUTPUT_3=$(run_client "$PORT_NAIVE" "$CERTS_DIR/server.crt")

echo ""
echo "$OUTPUT_3" | grep -E "Peer signature|Negotiated|Verification|error" || true
echo ""

VERIF_3=$(echo "$OUTPUT_3" | grep "Verification" || echo "Verification: (no trobat)")
if echo "$VERIF_3" | grep -qiE "error|FAILED|self.signed"; then
    echo "  ❌ ADVERSARI NAÏF: Verification: FAILED — detectable sense Shor"
    echo "     El certificat attacker_naive.crt no forma part de la cadena de"
    echo "     confiança del client. La PKI clàssica detecta l'impostora."
    echo "     CONTRAST: sense la clau privada robada, el MitM és immediatament"
    echo "     detectable, a diferència de l'Escenari 2."
fi

save_result "$RESULTS_DIR/a3_3_naive.txt" "$OUTPUT_3"

kill "$SRV_NAIVE_PID" 2>/dev/null; wait "$SRV_NAIVE_PID" 2>/dev/null || true
SRV_NAIVE_PID=""

# =============================================================================
# TAULA COMPARATIVA FINAL
# =============================================================================

print_header "COMPARACIÓ FINAL — 3 escenaris"

V1=$(echo "$OUTPUT_1" | grep "Verification" | awk '{print $NF}' || echo "?")
V2=$(echo "$OUTPUT_2" | grep "Verification" | awk '{print $NF}' || echo "?")
V3=$(echo "$OUTPUT_3" | grep "Verification" | awk '{print $NF}' || echo "error")

G1=$(echo "$OUTPUT_1" | grep "Negotiated TLS1.3 group" | awk '{print $NF}' || echo "?")
G2=$(echo "$OUTPUT_2" | grep "Negotiated TLS1.3 group" | awk '{print $NF}' || echo "?")
G3=$(echo "$OUTPUT_3" | grep "Negotiated TLS1.3 group" | awk '{print $NF}' || echo "?")

echo ""
echo "  ┌──────────────────────┬──────────────────────┬──────────────┬──────────────┬─────────────┐"
echo "  │ Escenari             │ Certificat           │ Clau         │ Verification │ Detectable? │"
echo "  ├──────────────────────┼──────────────────────┼──────────────┼──────────────┼─────────────┤"
printf "  │ 1. Servidor legítim  │ server.crt (legítim) │ server.key   │ %-12s │ N/A         │\n" "$V1"
printf "  │ 2. Rogue (Shor)      │ server.crt (legítim) │ stolen.key   │ %-12s │ ❌ NO       │\n" "$V2"
printf "  │ 3. Naïf (sense Shor) │ attacker_naive.crt   │ attacker.key │ %-12s │ ✅ SÍ       │\n" "$V3"
echo "  └──────────────────────┴──────────────────────┴──────────────┴──────────────┴─────────────┘"
echo ""
echo "  Grup negociat:"
echo "    Escenari 1: $G1"
echo "    Escenari 2: $G2  ← idèntic al legítim, indetectable"
echo "    Escenari 3: $G3"
echo ""
echo "  CONCLUSIÓ (Cap. 4 §4.2.3 + §4.3.1):"
echo "  La seguretat post-quàntica del canal (X25519MLKEM768) és ortogonal"
echo "  a la seguretat de l'autenticació (ECDSA P-256). Un adversari amb CRQC"
echo "  que apliqui Shor sobre la clau pública ECDSA del certificat obté"
echo "  sk_ECDSA i pot executar un MitM completament invisible (Escenari 2):"
echo "  Verification: OK, canal X25519MLKEM768, CertificateVerify vàlid."
echo "  Sense Shor (Escenari 3), el MitM és immediatament detectable per la PKI."
echo "  Aquesta és la debilitat residual estructural del §3.4: l'autenticació"
echo "  clàssica és el buit de seguretat principal del handshake híbrid actual."
echo ""
echo "  Fitxer keylog per a Wireshark: $RESULTS_DIR/tls_keys_a3.log"
echo "  Càrrega: Edit → Preferences → Protocols → TLS → (Pre)-Master-Secret log"
echo ""
