# PoC TLS 1.3 Híbrid X25519MLKEM768

**Autor**: Marti Armengol | **UPF** | **Març 2026**
**TFG**: Anàlisi de Seguretat del Handshake TLS 1.3 amb Criptografia Post-Quàntica Híbrida

## Descripció

Prova de concepte que demostra la negociació del grup híbrid post-quàntic
`X25519MLKEM768` (X25519 + ML-KEM-768 / FIPS 203) en TLS 1.3 real, usant
OpenSSL 3.5.4 + liboqs 0.15.0 + OQS-Provider 0.12.0.

## Evidències obtingudes

- `Negotiated TLS1.3 group: X25519MLKEM768` — output client OpenSSL
- `key_share X25519MLKEM768 (0x11ec), 1216 bytes` — captura Wireshark
- `psk_key_exchange_modes: psk_dhe_ke` — Forward Secrecy verificada

## Requisits

- Debian 13 Trixie (amd64) — OpenSSL 3.5.4 natiu
- CMake ≥ 3.20, GCC ≥ 11, Ninja
- ~3 GB d'espai lliure

## Instal·lació completa

```bash
cd setup/
./install_deps.sh
./build_liboqs.sh
./build_oqs_provider.sh
./gen_certs.sh

## Execució del PoC
bash
# Terminal 1 — Servidor
./poc/run_server.sh

# Terminal 2 — Client
./poc/run_client.sh

# Terminal 3 (opcional) — Captura
./poc/capture.sh

## Estructure
tfg-poc/
├── setup/
│   ├── install_deps.sh       # Dependències apt
│   ├── build_liboqs.sh       # Compilació liboqs 0.15.0
│   ├── build_oqs_provider.sh # Compilació OQS-Provider 0.12.0
│   └── gen_certs.sh          # Certificats ECDSA P-256 test
├── poc/
│   ├── run_server.sh         # Servidor TLS 1.3
│   ├── run_client.sh         # Client TLS 1.3
│   └── capture.sh            # Captura tcpdump
├── certs/                    # server.key + server.crt
├── captures/                 # .pcap + screenshots Wireshark
└── docs/
    └── poc_documentation.pdf # Document complet del PoC


