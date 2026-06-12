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

  # Prebuilt static lib (built by tools/build_ios_xcframework.sh).
  s.vendored_frameworks = 'Frameworks/SecretariatCore.xcframework'

  # It's a static library — force-load it so dart:ffi can resolve the symbols
  # at runtime (the linker would otherwise dead-strip the "unused" exports).
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-force_load "${PODS_TARGET_SRCROOT}/Frameworks/SecretariatCore.xcframework/ios-arm64/libsecretariat_core_ffi.a"',
  }
end
