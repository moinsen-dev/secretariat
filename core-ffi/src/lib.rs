//! C ABI around `secretariat-core` for FFI hosts (the iOS app via dart:ffi).
//!
//! All crypto runs in `secretariat-core`, so iOS, the daemon, and the CLI are
//! byte-identical. The encrypted blob format here is `nonce(12) || ciphertext`,
//! exactly the `value_encrypted` layout stored in the vault and synced via
//! iCloud — so the iOS app can decrypt the synced blobs directly.
//!
//! Memory contract: functions that return a buffer write a heap pointer to
//! `*out_ptr` and its length to `*out_len`. The caller MUST hand both back to
//! `sec_free` exactly once. Return value is 0 on success, negative on error.

use secretariat_core::{
    decrypt, derive_key_from_password, encrypt, EncryptedValue, KEY_SIZE, NONCE_SIZE,
};
use std::slice;

const ERR_NULL: i32 = -1;
const ERR_UTF8: i32 = -2;
const ERR_CRYPTO: i32 = -3;
const ERR_SHORT: i32 = -4;

/// Derive the 32-byte master key from a password and salt.
/// `out_key` must point to at least 32 writable bytes.
///
/// # Safety
/// Pointers must be valid for the given lengths; `out_key` for 32 bytes.
#[no_mangle]
pub unsafe extern "C" fn sec_derive_key(
    password: *const u8,
    password_len: usize,
    salt: *const u8,
    salt_len: usize,
    out_key: *mut u8,
) -> i32 {
    if password.is_null() || salt.is_null() || out_key.is_null() {
        return ERR_NULL;
    }
    let pw = slice::from_raw_parts(password, password_len);
    let salt_bytes = slice::from_raw_parts(salt, salt_len);
    let Ok(salt_str) = std::str::from_utf8(salt_bytes) else {
        return ERR_UTF8;
    };
    match derive_key_from_password(pw, salt_str) {
        Ok(key) => {
            std::ptr::copy_nonoverlapping(key.as_ptr(), out_key, KEY_SIZE);
            0
        }
        Err(_) => ERR_CRYPTO,
    }
}

/// Encrypt UTF-8 `plaintext` with the 32-byte `key`. Writes a heap buffer
/// (`nonce || ciphertext`) to `*out_ptr`/`*out_len`; free with `sec_free`.
///
/// # Safety
/// `key` must point to 32 bytes; out params must be valid pointers.
#[no_mangle]
pub unsafe extern "C" fn sec_encrypt(
    plaintext: *const u8,
    plaintext_len: usize,
    key: *const u8,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if plaintext.is_null() || key.is_null() || out_ptr.is_null() || out_len.is_null() {
        return ERR_NULL;
    }
    let pt_bytes = slice::from_raw_parts(plaintext, plaintext_len);
    let Ok(pt) = std::str::from_utf8(pt_bytes) else {
        return ERR_UTF8;
    };
    let mut k = [0u8; KEY_SIZE];
    std::ptr::copy_nonoverlapping(key, k.as_mut_ptr(), KEY_SIZE);

    match encrypt(pt, &k) {
        Ok(ev) => {
            let mut blob = Vec::with_capacity(NONCE_SIZE + ev.ciphertext.len());
            blob.extend_from_slice(&ev.nonce);
            blob.extend_from_slice(&ev.ciphertext);
            write_buffer(blob, out_ptr, out_len);
            0
        }
        Err(_) => ERR_CRYPTO,
    }
}

/// Decrypt a `nonce(12) || ciphertext` blob with the 32-byte `key`. Writes the
/// UTF-8 plaintext to `*out_ptr`/`*out_len`; free with `sec_free`.
///
/// # Safety
/// `key` must point to 32 bytes; out params must be valid pointers.
#[no_mangle]
pub unsafe extern "C" fn sec_decrypt(
    blob: *const u8,
    blob_len: usize,
    key: *const u8,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if blob.is_null() || key.is_null() || out_ptr.is_null() || out_len.is_null() {
        return ERR_NULL;
    }
    if blob_len < NONCE_SIZE {
        return ERR_SHORT;
    }
    let data = slice::from_raw_parts(blob, blob_len);
    let mut nonce = [0u8; NONCE_SIZE];
    nonce.copy_from_slice(&data[..NONCE_SIZE]);
    let ev = EncryptedValue {
        nonce,
        ciphertext: data[NONCE_SIZE..].to_vec(),
    };
    let mut k = [0u8; KEY_SIZE];
    std::ptr::copy_nonoverlapping(key, k.as_mut_ptr(), KEY_SIZE);

    match decrypt(&ev, &k) {
        Ok(plaintext) => {
            write_buffer(plaintext.into_bytes(), out_ptr, out_len);
            0
        }
        Err(_) => ERR_CRYPTO,
    }
}

/// Free a buffer returned by `sec_encrypt` / `sec_decrypt`.
///
/// # Safety
/// `ptr`/`len` must be exactly what a returning function produced, freed once.
#[no_mangle]
pub unsafe extern "C" fn sec_free(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        let s = std::slice::from_raw_parts_mut(ptr, len) as *mut [u8];
        drop(Box::from_raw(s));
    }
}

/// The key size, so callers can size their buffer without hardcoding it.
#[no_mangle]
pub extern "C" fn sec_key_size() -> usize {
    KEY_SIZE
}

/// Generate a fresh random salt (PHC base64), byte-identical to what the
/// daemon's vault-init produces — so an iOS-created vault unlocks on a Mac and
/// vice versa. Writes the UTF-8 salt string to `*out_ptr`/`*out_len`; free with
/// `sec_free`.
///
/// # Safety
/// `out_ptr`/`out_len` must be valid, writable pointers.
#[no_mangle]
pub unsafe extern "C" fn sec_generate_salt(out_ptr: *mut *mut u8, out_len: *mut usize) -> i32 {
    if out_ptr.is_null() || out_len.is_null() {
        return ERR_NULL;
    }
    let salt = secretariat_core::generate_salt();
    write_buffer(salt.into_bytes(), out_ptr, out_len);
    0
}

unsafe fn write_buffer(bytes: Vec<u8>, out_ptr: *mut *mut u8, out_len: *mut usize) {
    let boxed = bytes.into_boxed_slice();
    *out_len = boxed.len();
    *out_ptr = Box::into_raw(boxed) as *mut u8;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ffi_roundtrip_matches_core() {
        let salt = secretariat_core::generate_salt();
        let pw = b"correct horse battery staple";

        // Derive via FFI.
        let mut key = [0u8; KEY_SIZE];
        let rc = unsafe {
            sec_derive_key(pw.as_ptr(), pw.len(), salt.as_ptr(), salt.len(), key.as_mut_ptr())
        };
        assert_eq!(rc, 0);

        // Same key as calling core directly.
        let core_key = derive_key_from_password(pw, &salt).unwrap();
        assert_eq!(key, core_key);

        // Encrypt via FFI, decrypt via core.
        let plaintext = "sk-proj-secret-value";
        let mut blob_ptr: *mut u8 = std::ptr::null_mut();
        let mut blob_len: usize = 0;
        let rc = unsafe {
            sec_encrypt(
                plaintext.as_ptr(),
                plaintext.len(),
                key.as_ptr(),
                &mut blob_ptr,
                &mut blob_len,
            )
        };
        assert_eq!(rc, 0);
        let blob = unsafe { slice::from_raw_parts(blob_ptr, blob_len) };
        assert!(blob_len > NONCE_SIZE);
        let mut nonce = [0u8; NONCE_SIZE];
        nonce.copy_from_slice(&blob[..NONCE_SIZE]);
        let ev = EncryptedValue { nonce, ciphertext: blob[NONCE_SIZE..].to_vec() };
        assert_eq!(decrypt(&ev, &key).unwrap(), plaintext);

        // And decrypt via FFI.
        let mut out_ptr: *mut u8 = std::ptr::null_mut();
        let mut out_len: usize = 0;
        let rc = unsafe {
            sec_decrypt(blob_ptr, blob_len, key.as_ptr(), &mut out_ptr, &mut out_len)
        };
        assert_eq!(rc, 0);
        let got = unsafe { slice::from_raw_parts(out_ptr, out_len) };
        assert_eq!(std::str::from_utf8(got).unwrap(), plaintext);

        unsafe {
            sec_free(blob_ptr, blob_len);
            sec_free(out_ptr, out_len);
        }
    }
}
