# TFG PoC — TLS 1.3 Híbrid X25519MLKEM768

**TFG:** Seguretat Post-Quàntica en TLS 1.3: Anàlisi de Garanties i
Vulnerabilitats en Handshakes Híbrids X25519 + ML-KEM (FIPS 203)
**Autor:** Martí Armengol | UPF Enginyeria Informàtica | Març 2026

## Contingut

| Directori | Descripció |
|-----------|-----------|
| `setup/` | Scripts d'instal·lació (liboqs, OQS-Provider, certs) |
| `poc/` | PoC base: servidor + client TLS 1.3 X25519MLKEM768 |
| `attacks/A1_downgrade/` | Atac de downgrade de grup (3 escenaris) |
| `attacks/A2_0rtt_replay/` | Replay attack sobre 0-RTT Early Data |
| `attacks/A3_mitm_pki/` | MitM sobre PKI clàssica (debilitat autenticació) |
| `certs/` | Certificats ECDSA P-256 de test |

## Requisits
- Debian 13 Trixie / Ubuntu 22.04+
- OpenSSL 3.3+, liboqs 0.15.0, OQS-Provider 0.12.0

## Instal·lació ràpida
```bash
bash setup/install_deps.sh
bash setup/build_liboqs.sh
bash setup/build_oqs_provider.sh
bash setup/gen_certs.sh
```

## Execució PoC base
```bash
bash poc/run_server.sh   # Terminal 1
bash poc/run_client.sh   # Terminal 2
```

## Execució Atacs (Cap. 4)
```bash
bash attacks/A1_downgrade/run_attack_a1.sh
bash attacks/A2_0rtt_replay/run_attack_a2.sh
bash attacks/A3_mitm_pki/run_attack_a3.sh
```
