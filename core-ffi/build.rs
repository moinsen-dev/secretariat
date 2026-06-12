// On iOS the cdylib is shipped as an embedded dynamic framework. Set its
// install name to the @rpath the app expects so it loads at runtime.
fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "ios" {
        println!("cargo:rustc-cdylib-link-arg=-install_name");
        println!(
            "cargo:rustc-cdylib-link-arg=@rpath/SecretariatCore.framework/SecretariatCore"
        );
    }
}
