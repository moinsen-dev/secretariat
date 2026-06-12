Pod::Spec.new do |s|
  s.name             = 'secretariat_core'
  s.version          = '0.4.0'
  s.summary          = 'Secretariat shared crypto (Argon2id + AES-256-GCM) via FFI.'
  s.description       = 'Static xcframework of secretariat-core-ffi so the iOS app runs byte-identical crypto. Symbols are reached from Dart via dart:ffi (DynamicLibrary.process()).'
  s.homepage         = 'https://secretariat.moinsen.dev'
  s.license          = { :type => 'BSL-1.1' }
  s.author           = { 'Moinsen' => 'uli@moinsen.dev' }
  s.platform         = :ios, '13.0'
  s.source           = { :path => '.' }

  # Built by tools/build_ios_xcframework.sh. We don't use vendored_frameworks
  # (its auto-link of a static-lib xcframework fights slice extraction/ordering
  # in Flutter's build). Instead force-load the matching slice per SDK: the
  # source .a always exists (no "missing build input"), force_load keeps the
  # C symbols for dart:ffi, and there's no double-link.
  s.preserve_paths   = 'Frameworks/SecretariatCore.xcframework'
  # -u marks the symbols as required so the linker keeps them in the dynamic
  # symbol table (dart:ffi resolves them via dlsym) instead of dead-stripping
  # the force-loaded-but-unreferenced exports.
  keep = '-Wl,-u,_sec_derive_key -Wl,-u,_sec_encrypt -Wl,-u,_sec_decrypt -Wl,-u,_sec_free -Wl,-u,_sec_key_size'
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS[sdk=iphoneos*]'        => "$(inherited) #{keep} -force_load ${PODS_ROOT}/../Frameworks/SecretariatCore.xcframework/ios-arm64/libsecretariat_core_ffi.a",
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => "$(inherited) #{keep} -force_load ${PODS_ROOT}/../Frameworks/SecretariatCore.xcframework/ios-arm64_x86_64-simulator/libsecretariat_core_ffi.a",
  }
end
