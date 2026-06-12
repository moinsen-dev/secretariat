Pod::Spec.new do |s|
  s.name             = 'secretariat_core'
  s.version          = '0.4.0'
  s.summary          = 'Secretariat shared crypto (Argon2id + AES-256-GCM) via FFI.'
  s.description       = 'Dynamic framework of secretariat-core-ffi so the iOS app runs byte-identical crypto. Symbols are reached from Dart via dart:ffi (DynamicLibrary.process()).'
  s.homepage         = 'https://secretariat.moinsen.dev'
  s.license          = { :type => 'BSL-1.1' }
  s.author           = { 'Moinsen' => 'uli@moinsen.dev' }
  s.platform         = :ios, '13.0'
  s.source           = { :path => '.' }

  # Prebuilt DYNAMIC framework (tools/build_ios_xcframework.sh). CocoaPods
  # embeds + code-signs it into the app; its symbols are exported (not
  # dead-stripped like a static lib), so dart:ffi resolves them at runtime via
  # DynamicLibrary.process().
  s.vendored_frameworks = 'Frameworks/SecretariatCore.xcframework'
end
