# PoC TLS 1.3 Híbrid X25519MLKEM768 — Notes de Documentació
**Autor**: Marti Armengol | **Data**: Març 2026 | **TFG**: UPF

---

## Entorn d'Execució

| Component        | Versió / Detall                          |
|------------------|------------------------------------------|
| Sistema Operatiu | Debian 13 Trixie (amd64)                 |
| CPU              | Intel Core Ultra 7 155U (12 cores, AVX2) |
| RAM              | 32 GB                                    |
| OpenSSL          | 3.5.4 (30 Sep 2025) — paquet Debian natiu|
| libssl-dev       | 3.5.4-1~deb13u2                          |
| liboqs           | 0.15.0 — compilat des de GitHub          |
| OQS-Provider     | [omplir al pas 2.3]                      |
| Wireshark        | 4.4.13                                   |
| tcpdump          | 4.99.5                                   |
| CMake            | 3.31.6                                   |
| GCC              | 14.2.0 (Debian)                          |

---

## Pas 2.2 — Compilació de liboqs 0.15.0

**Repositori**: https://github.com/open-quantum-safe/liboqs  
**Commit**: (HEAD, depth 1, març 2026)  
**Flags de compilació rellevants**:
- `OQS_DIST_BUILD=ON` → build optimitzat per a la CPU actual
- `OQS_USE_AVX2_INSTRUCTIONS=ON` → ML-KEM amb acceleració Intel AVX2
- `BUILD_SHARED_LIBS=ON` → genera liboqs.so per a linkatge dinàmic
- `CMAKE_BUILD_TYPE=Release` → optimitzacions de compilador actives

**Algorismes instal·lats rellevants**:
- `kem_ml_kem.h` → ML-KEM-512 / ML-KEM-768 / ML-KEM-1024 (FIPS 203)
- `sig_ml_dsa.h` → ML-DSA (FIPS 204) — algorisme de signatura PQC
- `sig_slh_dsa.h` → SLH-DSA (FIPS 205)

**Ruta d'instal·lació**: `~/tfg-poc/liboqs-install/`

**Output de verificació**:
- `liboqs.so.0.15.0` present a `lib/`
- `kem_ml_kem.h` present a `include/oqs/`

**Connexió amb el TFG**:
- La presència de `sig_ml_dsa.h` confirma que liboqs 0.15.0 implementa
  ML-DSA (FIPS 204), el mecanisme de signatura que resoldria la debilitat
  d'autenticació documentada a §3.4, però que no és usat en el handshake
  TLS 1.3 estàndard actual.

---

## Pas 2.3 — OQS-Provider
Versió: 0.12.0-dev (commit e2aed51)
Instal·lat a: /usr/lib/x86_64-linux-gnu/ossl-modules/oqsprovider.so
Problema trobat: liboqs.so.9 no al path del linker
Solució: /etc/ld.so.conf.d/liboqs.conf + sudo ldconfig


## Pas 2.4 — Certificats de test [pendent]

## Pas 2.5 — Execució servidor [pendent]

openssl s_server \
    -cert server.crt \
    -key server.key \
    -port 4433 \
    -tls1_3 \
    -groups X25519MLKEM768 \
    -provider oqsprovider \
    -provider default \
    -www
Using default temp DH parameters
ACCEPT


## Pas 2.6 — Execució client [pendent]

openssl s_client \
    -connect localhost:4433 \
    -tls1_3 \
    -groups X25519MLKEM768 \
    -provider oqsprovider \
    -provider default \
    -CAfile server.crt \
    -brief
Connecting to 127.0.0.1
Can't use SSL_get_servername
CONNECTION ESTABLISHED
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Peer certificate: CN=localhost, O=TFG-PoC-UPF, C=ES
Hash used: SHA256
Signature type: ecdsa_secp256r1_sha256
Verification: OK
Negotiated TLS1.3 group: X25519MLKEM768



## Pas 2.7 — Captura Wireshark [pendent]

Frame 4: 1542 bytes on wire (12336 bits), 1542 bytes captured (12336 bits)
Ethernet II, Src: 00:00:00_00:00:00 (00:00:00:00:00:00), Dst: 00:00:00_00:00:00 (00:00:00:00:00:00)
Internet Protocol Version 4, Src: 127.0.0.1, Dst: 127.0.0.1
Transmission Control Protocol, Src Port: 58456, Dst Port: 4433, Seq: 1, Ack: 1, Len: 1476
Transport Layer Security
    TLSv1.3 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 1471
        Handshake Protocol: Client Hello
            Handshake Type: Client Hello (1)
            Length: 1467
            Version: TLS 1.2 (0x0303)
            Random: 84ba1581a58377b7090517f926a98f7aaf95469a2b09d2d504e49d17668b5c99
            Session ID Length: 32
            Session ID: 3c37bb776501774bc7717fef28bf513f74f769201141d5d4437fa9eccab1848e
            Cipher Suites Length: 6
            Cipher Suites (3 suites)
            Compression Methods Length: 1
            Compression Methods (1 method)
            Extensions Length: 1388
            Extension: supported_groups (len=4)
                Type: supported_groups (10)
                Length: 4
                Supported Groups List Length: 2
                Supported Groups (1 group)
                    Supported Group: X25519MLKEM768 (0x11ec)
            Extension: session_ticket (len=0)
                Type: session_ticket (35)
                Length: 0
                Session Ticket: <MISSING>
            Extension: encrypt_then_mac (len=0)
                Type: encrypt_then_mac (22)
                Length: 0
            Extension: extended_master_secret (len=0)
                Type: extended_master_secret (23)
                Length: 0
            Extension: signature_algorithms (len=116)
                Type: signature_algorithms (13)
                Length: 116
                Signature Hash Algorithms Length: 114
                Signature Hash Algorithms (57 algorithms)
            Extension: supported_versions (len=3) TLS 1.3
                Type: supported_versions (43)
                Length: 3
                Supported Versions length: 2
                Supported Version: TLS 1.3 (0x0304)
            Extension: psk_key_exchange_modes (len=2)
                Type: psk_key_exchange_modes (45)
                Length: 2
                PSK Key Exchange Modes Length: 1
                PSK Key Exchange Mode: PSK with (EC)DHE key establishment (psk_dhe_ke) (1)
            Extension: key_share (len=1222) X25519MLKEM768
                Type: key_share (51)
                Length: 1222
                Key Share extension
                    Client Key Share Length: 1220
                    Key Share Entry: Group: X25519MLKEM768, Key Exchange length: 1216
            Extension: compress_certificate (len=5)
                Type: compress_certificate (27)
                Length: 5
                Algorithms Length: 4
                Algorithm: zlib (1)
                Algorithm: zstd (3)
            [JA4: t13i030900_55b375c5d22e_56d35dc6e0bc]
            [JA4_r […]: t13i030900_1301,1302,1303_000a,000d,0016,0017,001b,0023,002b,002d,0033_0905,0906,0904,0403,0503,0603,0807,0808,081a,081b,081c,0809,080a,080b,0804,0805,0806,0401,0501,0601,ff06,ff07,ff08,ff09,fed7,fed8,fed9,fedc,fedd,fede,feda,]
            [JA3 Fullstring: 771,4866-4867-4865,10-35-22-23-13-43-45-51-27,4588,]
            [JA3: 7da08346467f6cfa9dac570795c6b760]

**Fitxer**: captures/poc_tls_hybrid.pcap
**Eina**: Wireshark 4.4.13 + tcpdump 4.99.5
**Interfície capturada**: loopback (lo), port 4433

### Evidències documentades al ClientHello (Frame 4)

| Camp Wireshark | Valor | Significat per al TFG |
|----------------|-------|----------------------|
| `supported_groups` | `X25519MLKEM768 (0x11ec)` | Grup híbrid PQC negociat — §3.2 |
| `supported_versions` | `TLS 1.3 (0x0304)` | Protocol TLS 1.3 forçat — §2.1 |
| `key_share` grup | `X25519MLKEM768` | Clau pública híbrida enviada |
| `key_share` longitud | `1216 bytes` | 32B (X25519) + 1184B (ML-KEM-768) |
| `psk_key_exchange_modes` | `psk_dhe_ke (1)` | FS garantida, mode psk_ke deshabilitat — §3.3 |

### Connexions amb l'anàlisi teòrica del TFG

**§3.2 Confidencialitat**: la presència de `key_share X25519MLKEM768` de 1216 bytes
confirma que el client envia simultàniament la clau pública X25519 (32 bytes) i la
clau d'encapsulació ML-KEM-768 (1184 bytes). Cap adversari clàssic o quàntic pot
reconstruir SS_hybrid sense disposar de la clau privada efímera ML-KEM del client.

**§3.3 Forward Secrecy**: el mode `psk_dhe_ke (1)` confirma que qualsevol reanudació
de sessió inclourà nou material efímer. El mode `psk_ke` (sense efímer, que trencaria
la FS) no està ofert pel client.

**§3.4 Autenticació**: l'output del client mostra `Signature type: ecdsa_secp256r1_sha256`,
confirmant empíricament que l'autenticació del servidor usa ECDSA P-256 — un algorisme
vulnerable a l'algorisme de Shor. Aquesta és la debilitat residual documentada a §3.4.

**§3.5 Resistència HNDL**: la condició C1 (negociació efectiva del grup híbrid) està
verificada. La condició C3 (descart de claus efímeres) és garantida per l'especificació
TLS 1.3 i la implementació OpenSSL 3.5.4.

            
## Anàlisi i Conclusions [pendent]
