#ifndef SECRETARIAT_CORE_FFI_H
#define SECRETARIAT_CORE_FFI_H

#include <stddef.h>
#include <stdint.h>

/* C ABI around secretariat-core (Argon2id + AES-256-GCM).
 * Returns 0 on success, negative on error. Buffers returned via out params
 * must be freed once with sec_free. Blob layout: nonce(12) || ciphertext. */

int32_t sec_derive_key(const uint8_t *password, size_t password_len,
                       const uint8_t *salt, size_t salt_len,
                       uint8_t *out_key /* 32 bytes */);

int32_t sec_encrypt(const uint8_t *plaintext, size_t plaintext_len,
                    const uint8_t *key /* 32 bytes */,
                    uint8_t **out_ptr, size_t *out_len);

int32_t sec_decrypt(const uint8_t *blob, size_t blob_len,
                    const uint8_t *key /* 32 bytes */,
                    uint8_t **out_ptr, size_t *out_len);

void sec_free(uint8_t *ptr, size_t len);

size_t sec_key_size(void);

/* Generate a fresh PHC-base64 salt string (UTF-8) for a new vault, matching the
 * daemon's vault-init. Free the buffer once with sec_free. */
int32_t sec_generate_salt(uint8_t **out_ptr, size_t *out_len);

#endif /* SECRETARIAT_CORE_FFI_H */
