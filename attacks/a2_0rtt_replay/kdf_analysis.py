import hashlib, hmac, struct

def hkdf_extract(salt, ikm, hash_algo='sha384'):
    if salt is None:
        salt = bytes(hashlib.new(hash_algo).digest_size)
    return hmac.new(salt, ikm, hash_algo).digest()

def hkdf_expand_label(secret, label, context, length, hash_algo='sha384'):
    full_label = b"tls13 " + label.encode()
    hkdf_label = (struct.pack('>H', length) +
                  bytes([len(full_label)]) + full_label +
                  bytes([len(context)]) + context)
    return hmac.new(secret, hkdf_label + b'\x01', hash_algo).digest()[:length]

hash_algo = 'sha384'
hash_len  = 48

PSK     = b'\xAB' * hash_len   # PSK fix (contingut del session ticket)
CH_hash = b'\x11' * hash_len   # Hash ClientHello (públic, al transcript)
DHE     = b'\x7F' * hash_len   # K_KEM || K_ECDH (efímer, inaccessible)

zeros        = bytes(hash_len)
early_secret = hkdf_extract(zeros, PSK, hash_algo)
K_early      = hkdf_expand_label(early_secret, "c e traffic", CH_hash, hash_len, hash_algo)

derived      = hkdf_expand_label(early_secret, "derived", b'', hash_len, hash_algo)
hs_secret    = hkdf_extract(derived, DHE, hash_algo)
K_handshake  = hkdf_expand_label(hs_secret, "c hs traffic", CH_hash, hash_len, hash_algo)

print("=" * 65)
print("TLS 1.3 Key Schedule — Anàlisi de Replay 0-RTT")
print("=" * 65)
print(f"\nPSK (session ticket secret) : {PSK.hex()[:32]}...")
print(f"ClientHello hash (públic)   : {CH_hash.hex()[:32]}...")
print(f"DHE = K_KEM || K_ECDH (priv): {DHE.hex()[:32]}...")

print("\n--- PATH 1: Early Traffic Secret (0-RTT) ---")
print(f"  early_secret : {early_secret.hex()[:32]}...")
print(f"  K_early      : {K_early.hex()[:32]}...")
print("  Depèn de: PSK + CH_hash")
print("  K_KEM absent  /  K_ECDH absent")
print("  -> Mateix PSK + mateix CH_hash = mateixa K_early = REPLAY POSSIBLE")

print("\n--- PATH 2: Handshake Traffic Secret (canal normal) ---")
print(f"  handshake_secret : {hs_secret.hex()[:32]}...")
print(f"  K_handshake      : {K_handshake.hex()[:32]}...")
print("  Depèn de: PSK + DHE (K_KEM || K_ECDH)")
print("  K_KEM present  /  K_ECDH present")
print("  -> Efimer nou cada sessio = K_handshake diferent = REPLAY IMPOSSIBLE")

K_early_replay = hkdf_expand_label(
    hkdf_extract(zeros, PSK, hash_algo),
    "c e traffic", CH_hash, hash_len, hash_algo)

print("\n--- Verificacio del Replay ---")
print(f"  K_early original : {K_early.hex()[:32]}...")
print(f"  K_early replay   : {K_early_replay.hex()[:32]}...")
print(f"  Iguals: {K_early == K_early_replay}  <- atacant pot desxifrar/reenviar")
