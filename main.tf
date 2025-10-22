terraform {
  required_version = "~>1.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_iam_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach basic execution role for Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach explicit CloudWatch permissions
resource "aws_iam_policy" "lambda_cloudwatch_policy" {
  name        = "lambda-cloudwatch-logs-policy"
  description = "Policy to allow Lambda to write to CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_policy.arn
}

# Package the Lambda function code
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.js"
  output_path = "${path.module}/lambda/lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "crud_lambda" {
  function_name    = "crud-lambda-function"
  role             = aws_iam_role.lambda_iam_role.arn
  handler          = "lambda_function.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
}



# API Gateway
resource "aws_apigatewayv2_api" "Http_api" {
  name          = "http-api"
  protocol_type = "HTTP"
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.Http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.crud_lambda.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Routes
# Root route "/" → Hello from Lambda
resource "aws_apigatewayv2_route" "root_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# CRUD routes for /user
resource "aws_apigatewayv2_route" "get_user_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "GET /user"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "post_user_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "POST /user"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "put_user_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "PUT /user"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "delete_user_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "DELETE /user"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda Permission
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crud_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.Http_api.execution_arn}/*"
}

# Deployment stage
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.Http_api.id
  name        = "$default"   # Use default stage
  auto_deploy = true
}

# Output API URL
output "api_invoke_url" {
  value = aws_apigatewayv2_api.Http_api.api_endpoint
}
