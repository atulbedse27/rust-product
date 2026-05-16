########################################
# PROVIDER
########################################

provider "aws" {
  region = var.aws_region
}

########################################
# IAM ROLE FOR LAMBDA
########################################

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

########################################
# CLOUDWATCH LOG POLICY
########################################

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

########################################
# DYNAMODB TABLE
########################################

resource "aws_dynamodb_table" "products_table" {

  name         = "products"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "product_id"

  attribute {
    name = "product_id"
    type = "S"
  }
}

########################################
# MOCK PRODUCT DATA
########################################

resource "aws_dynamodb_table_item" "product_1" {

  table_name = aws_dynamodb_table.products_table.name
  hash_key   = aws_dynamodb_table.products_table.hash_key

  item = <<ITEM
{
  "product_id": {"S": "101"},
  "sku": {"S": "IPHONE15-256"},
  "name": {"S": "iPhone 15 Pro"},
  "description": {"S": "Apple iPhone 15 Pro 256GB"},
  "brand": {"S": "Apple"},

  "category": {
    "M": {
      "id": {"S": "mobiles"},
      "name": {"S": "Mobile Phones"}
    }
  },

  "price": {
    "M": {
      "base_price": {"N": "1499"},
      "sale_price": {"N": "1399"},
      "currency": {"S": "USD"}
    }
  },

  "inventory": {
    "M": {
      "available": {"BOOL": true},
      "online": {"BOOL": true},
      "stock": {"N": "50"},
      "reserved": {"N": "5"},
      "warehouse_location": {"S": "Mumbai-WH1"}
    }
  },

  "attributes": {
    "M": {
      "color": {"S": "Black"},
      "storage": {"S": "256GB"},
      "ram": {"S": "8GB"}
    }
  },

  "flags": {
    "M": {
      "new_arrival": {"BOOL": true},
      "featured": {"BOOL": true},
      "best_seller": {"BOOL": true},
      "returnable": {"BOOL": true}
    }
  },

  "ratings": {
    "M": {
      "average_rating": {"N": "4.8"},
      "review_count": {"N": "1200"}
    }
  },

  "status": {"S": "ACTIVE"},
  "created_at": {"S": "2026-05-16T10:00:00Z"},
  "last_updated": {"S": "2026-05-16T10:00:00Z"}
}
ITEM
}

########################################
# DYNAMODB ACCESS POLICY
########################################

resource "aws_iam_policy" "dynamodb_policy" {

  name = "lambda_dynamodb_policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan"
        ]

        Resource = aws_dynamodb_table.products_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

########################################
# GET PRODUCT LAMBDA
########################################

resource "aws_lambda_function" "get_product" {

  function_name = "get_product"

  role    = aws_iam_role.lambda_exec_role.arn
  handler = "bootstrap"

  runtime = "provided.al2023"

  architectures = ["x86_64"]

  filename         = "${path.module}/../functions/rust-product-get/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../functions/rust-product-get/function.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.products_table.name
    }
  }
}

########################################
# POST PRODUCT LAMBDA
########################################

resource "aws_lambda_function" "post_product" {

  function_name = "post_product"

  role    = aws_iam_role.lambda_exec_role.arn
  handler = "bootstrap"

  runtime = "provided.al2023"

  architectures = ["x86_64"]

  filename         = "${path.module}/../functions/rust-product-post/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../functions/rust-product-post/function.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.products_table.name
    }
  }
}

########################################
# API GATEWAY
########################################

resource "aws_apigatewayv2_api" "api" {

  name          = "product-api"
  protocol_type = "HTTP"
}

########################################
# GET INTEGRATION
########################################

resource "aws_apigatewayv2_integration" "get_integration" {

  api_id = aws_apigatewayv2_api.api.id

  integration_type = "AWS_PROXY"

  integration_uri = aws_lambda_function.get_product.invoke_arn

  payload_format_version = "2.0"
}

########################################
# POST INTEGRATION
########################################

resource "aws_apigatewayv2_integration" "post_integration" {

  api_id = aws_apigatewayv2_api.api.id

  integration_type = "AWS_PROXY"

  integration_uri = aws_lambda_function.post_product.invoke_arn

  payload_format_version = "2.0"
}

########################################
# ROUTES
########################################

resource "aws_apigatewayv2_route" "get_route" {

  api_id = aws_apigatewayv2_api.api.id

  route_key = "GET /product/{id}"

  target = "integrations/${aws_apigatewayv2_integration.get_integration.id}"
}

resource "aws_apigatewayv2_route" "post_route" {

  api_id = aws_apigatewayv2_api.api.id

  route_key = "POST /product"

  target = "integrations/${aws_apigatewayv2_integration.post_integration.id}"
}

########################################
# STAGE
########################################

resource "aws_apigatewayv2_stage" "default" {

  api_id = aws_apigatewayv2_api.api.id

  name = "$default"

  auto_deploy = true
}

########################################
# API GATEWAY -> LAMBDA PERMISSION
########################################

resource "aws_lambda_permission" "allow_get" {

  statement_id = "AllowAPIGatewayInvokeGet"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.get_product.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_post" {

  statement_id = "AllowAPIGatewayInvokePost"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.post_product.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
