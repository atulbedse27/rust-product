use lambda_runtime::{service_fn, LambdaEvent, Error};
use serde_json::{json, Value};
use tracing_subscriber;
use tracing::info;

async fn handler(event: LambdaEvent<Value>) -> Result<Value, Error> {
    info!("REQUEST: {:?}", event.payload);
    info!("RESPONSE: {}", "success");
    Ok(json!({
        "statusCode": 200,
        "body": "Product is successfully stored."
    }))
    
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt().init();
    lambda_runtime::run(service_fn(handler)).await?;
    Ok(())
}