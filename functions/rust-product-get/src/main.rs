use aws_config::meta::region::RegionProviderChain;

use aws_lambda_events::event::apigw::{
    ApiGatewayV2httpRequest,
    ApiGatewayV2httpResponse,
};

use aws_sdk_dynamodb::{
    types::AttributeValue,
    Client,
};

use lambda_runtime::{service_fn, Error, LambdaEvent};

use serde_json::json;

use std::env;

use tracing::{error, info};
use aws_lambda_events::encodings::Body;
async fn handler(
    event: LambdaEvent<ApiGatewayV2httpRequest>,
) -> Result<ApiGatewayV2httpResponse, Error> {

    // =========================
    // REQUEST LOG
    // =========================

    let request = event.payload;

    info!("REQUEST: {:?}", request);

    // =========================
    // GET PRODUCT ID
    // =========================

    let product_id = request
        .path_parameters
        .get("id")
        .unwrap_or(&"".to_string())
        .clone();

    // =========================
    // VALIDATION
    // =========================

    if product_id.is_empty() {

        let mut api_response = ApiGatewayV2httpResponse::default();

        api_response.status_code = 400;

       api_response.body = Some(
            Body::Text(
                json!({
                    "message": "Product ID is required"
                })
                .to_string(),
            )
        );

        return Ok(api_response);
    }

    // =========================
    // DYNAMODB CONFIG
    // =========================

    let table_name =
        env::var("TABLE_NAME").unwrap_or("products".to_string());

    let region_provider =
        RegionProviderChain::default_provider().or_else("ap-south-1");

    let config = aws_config::from_env()
        .region(region_provider)
        .load()
        .await;

    let client = Client::new(&config);

    // =========================
    // FETCH PRODUCT
    // =========================

    let result = client
        .get_item()
        .table_name(table_name)
        .key(
            "product_id",
            AttributeValue::S(product_id.clone()),
        )
        .send()
        .await?;

    // =========================
    // RESPONSE
    // =========================

    match result.item {

        Some(item) => {

            let response = json!({

                "product_id": item.get("product_id")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "sku": item.get("sku")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "name": item.get("name")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "description": item.get("description")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "brand": item.get("brand")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "status": item.get("status")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "created_at": item.get("created_at")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),

                "last_updated": item.get("last_updated")
                    .and_then(|v| v.as_s().ok())
                    .map(|s| s.to_string())
                    .unwrap_or_default(),
            });

            info!("RESPONSE: {:?}", response);

            let mut api_response =
                ApiGatewayV2httpResponse::default();

            api_response.status_code = 200;

            api_response.body = Some(
                Body::Text(
                    serde_json::to_string_pretty(&response)?
                )
            );

            Ok(api_response)
        }

        None => {

            error!("Product not found");

            let mut api_response =
                ApiGatewayV2httpResponse::default();

            api_response.status_code = 404;

            api_response.body = Some(
                Body::Text(
                    json!({
                        "message": "Product not found"
                    })
                    .to_string(),
                )
            );

            Ok(api_response)
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {

    tracing_subscriber::fmt().init();

    lambda_runtime::run(service_fn(handler)).await?;

    Ok(())
}