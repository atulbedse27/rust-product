use aws_config::meta::region::RegionProviderChain;

use aws_lambda_events::{
    encodings::Body,
    event::apigw::{
        ApiGatewayV2httpRequest,
        ApiGatewayV2httpResponse,
    },
};

use aws_sdk_dynamodb::{
    types::AttributeValue,
    Client,
};

use http::{
    HeaderMap,
    HeaderValue,
};

use lambda_runtime::{service_fn, Error, LambdaEvent};

use serde::{Deserialize, Serialize};

use serde_json::json;

use std::env;

use tracing::{error, info};

#[derive(Debug, Serialize, Deserialize)]
struct Product {
    product_id: String,
    sku: String,
    name: String,
    description: String,
    brand: String,
    status: String,
    created_at: String,
    last_updated: String,
}

async fn handler(
    event: LambdaEvent<ApiGatewayV2httpRequest>,
) -> Result<ApiGatewayV2httpResponse, Error> {

    // =========================
    // REQUEST
    // =========================

    let request = event.payload;

    info!("REQUEST: {:?}", request);

    // =========================
    // REQUEST BODY
    // =========================

    let body = match request.body {

        Some(body) => body,

        None => {

            let mut response =
                ApiGatewayV2httpResponse::default();

            response.status_code = 400;

            response.body = Some(
                Body::Text(
                    json!({
                        "message": "Request body is required"
                    })
                    .to_string(),
                )
            );

            return Ok(response);
        }
    };

    // =========================
    // DESERIALIZE PRODUCT
    // =========================

    let product: Product = match serde_json::from_str(&body) {

        Ok(product) => product,

        Err(err) => {

            error!("Invalid request body: {:?}", err);

            let mut response =
                ApiGatewayV2httpResponse::default();

            response.status_code = 400;

            response.body = Some(
                Body::Text(
                    json!({
                        "message": "Invalid JSON payload"
                    })
                    .to_string(),
                )
            );

            return Ok(response);
        }
    };

    // =========================
    // DYNAMODB CONFIG
    // =========================

    let table_name =
        env::var("TABLE_NAME")
            .unwrap_or("products".to_string());

    let region_provider =
        RegionProviderChain::default_provider()
            .or_else("ap-south-1");

    let config = aws_config::from_env()
        .region(region_provider)
        .load()
        .await;

    let client = Client::new(&config);

    // =========================
    // SAVE PRODUCT
    // =========================

    client
        .put_item()
        .table_name(table_name)
        .item(
            "product_id",
            AttributeValue::S(product.product_id.clone()),
        )
        .item(
            "sku",
            AttributeValue::S(product.sku.clone()),
        )
        .item(
            "name",
            AttributeValue::S(product.name.clone()),
        )
        .item(
            "description",
            AttributeValue::S(product.description.clone()),
        )
        .item(
            "brand",
            AttributeValue::S(product.brand.clone()),
        )
        .item(
            "status",
            AttributeValue::S(product.status.clone()),
        )
        .item(
            "created_at",
            AttributeValue::S(product.created_at.clone()),
        )
        .item(
            "last_updated",
            AttributeValue::S(product.last_updated.clone()),
        )
        .send()
        .await?;

    // =========================
    // SUCCESS RESPONSE
    // =========================

    let response_body = json!({
        "message": "Product created successfully",
        "product": product
    });

    let mut response =
        ApiGatewayV2httpResponse::default();

    response.status_code = 201;

    let mut headers = HeaderMap::new();

    headers.insert(
        "content-type",
        HeaderValue::from_static("application/json"),
    );

    response.headers = headers;

    response.body = Some(
        Body::Text(
            serde_json::to_string_pretty(&response_body)?
        )
    );

    info!("RESPONSE: {:?}", response_body);

    Ok(response)
}

#[tokio::main]
async fn main() -> Result<(), Error> {

    tracing_subscriber::fmt().init();

    lambda_runtime::run(service_fn(handler)).await?;

    Ok(())
}