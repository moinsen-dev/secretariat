use secretariat::Secretariat;

fn main() {
    println!("Testing Rust SDK...\n");
    
    // Test 1: Create client
    let client = match Secretariat::new() {
        Ok(c) => {
            println!("✓ Client created successfully");
            c
        }
        Err(e) => {
            println!("✗ Failed to create client: {}", e);
            return;
        }
    };
    
    // Test 2: Set a secret
    match client.set("RUST_SDK_TEST", "rust_test_value_123") {
        Ok(()) => println!("✓ Set secret RUST_SDK_TEST"),
        Err(e) => {
            println!("✗ Failed to set secret: {}", e);
            return;
        }
    }
    
    // Test 3: Get the secret back
    match client.get("RUST_SDK_TEST") {
        Ok(value) => {
            if value == "rust_test_value_123" {
                println!("✓ Get secret returned correct value: {}", value);
            } else {
                println!("✗ Get secret returned wrong value: {} (expected rust_test_value_123)", value);
            }
        }
        Err(e) => {
            println!("✗ Failed to get secret: {}", e);
            return;
        }
    }
    
    // Test 4: List secrets
    match client.list() {
        Ok(secrets) => {
            println!("✓ List secrets returned {} secrets", secrets.len());
            if secrets.contains(&"RUST_SDK_TEST".to_string()) {
                println!("  ✓ RUST_SDK_TEST found in list");
            } else {
                println!("  ✗ RUST_SDK_TEST not found in list");
            }
        }
        Err(e) => println!("✗ Failed to list secrets: {}", e),
    }
    
    // Test 5: Delete the secret
    match client.delete("RUST_SDK_TEST") {
        Ok(()) => println!("✓ Deleted secret RUST_SDK_TEST"),
        Err(e) => println!("✗ Failed to delete secret: {}", e),
    }
    
    // Verify deletion
    match client.get("RUST_SDK_TEST") {
        Ok(_) => println!("✗ Secret still exists after deletion"),
        Err(_) => println!("✓ Secret no longer exists after deletion"),
    }
    
    println!("\n=== Rust SDK Test Complete ===");
}
