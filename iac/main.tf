provider "aws" {
  region = var.aws_region
}

############################
# IAM ROLE FOR LAMBDA
############################

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################
# LAMBDA FUNCTIONS (RUST)
############################

resource "aws_lambda_function" "get_product" {
  function_name = "get_product"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"

  filename         = "${path.module}/${var.get_zip_path}"
  source_code_hash = filebase64sha256("${path.module}/${var.get_zip_path}")
}

resource "aws_lambda_function" "post_product" {
  function_name = "post_product"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"

  filename         = "${path.module}/${var.post_zip_path}"
  source_code_hash = filebase64sha256("${path.module}/${var.post_zip_path}")
}

############################
# API GATEWAY (HTTP API)
############################

resource "aws_apigatewayv2_api" "api" {
  name          = "product-api"
  protocol_type = "HTTP"
}

############################
# INTEGRATIONS
############################

resource "aws_apigatewayv2_integration" "get_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_product.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "post_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.post_product.invoke_arn
  payload_format_version = "2.0"
}

############################
# ROUTES
############################

resource "aws_apigatewayv2_route" "get_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /product"
  target    = "integrations/${aws_apigatewayv2_integration.get_integration.id}"
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /product"
  target    = "integrations/${aws_apigatewayv2_integration.post_integration.id}"
}

############################
# STAGE (AUTO DEPLOY)
############################

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

############################
# PERMISSIONS (CRITICAL)
############################

resource "aws_lambda_permission" "allow_get" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_product.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_post" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_product.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
