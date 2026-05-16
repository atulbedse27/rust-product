use lambda_runtime::{service_fn, LambdaEvent, Error};
use serde_json::{json, Value};

async fn handler(_event: LambdaEvent<Value>) -> Result<Value, Error> {
    Ok(json!({
        "statusCode": 200,
        "body": "Product is successfully fetched."
    }))
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    lambda_runtime::run(service_fn(handler)).await?;
    Ok(())
}