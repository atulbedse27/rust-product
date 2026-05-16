# rust-product

cargo build --release --target x86_64-unknown-linux-musl

cp target/x86_64-unknown-linux-musl/release/rust-product-get functions/rust-product-get/bootstrap && chmod +x functions/rust-product-get/bootstrap && cd functions/rust-product-get && zip -j function.zip bootstrap && cd ../.. && cp target/x86_64-unknown-linux-musl/release/rust-product-post functions/rust-product-post/bootstrap && chmod +x functions/rust-product-post/bootstrap && cd functions/rust-product-post && zip -j function.zip bootstrap && cd ../..
