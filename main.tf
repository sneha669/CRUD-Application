# Terraform Block
terraform {
    required_version = "~>1.12"
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~>5.0"
      }
    }
}

# Provider Block
provider "aws" {
    region = "us-east-1"
    profile = "default"
}



#  Creating lambda function
resource "aws_lambda_function" "crud_lambda" {
  function_name    = "crud-lambda-function"
  role             = aws_iam_role.lambda_iam_role.arn
  handler          = "lambda_function.handler"
  runtime          = "nodejs20.x"
  
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
}


# IAM Role for lambda

resource "aws_iam_role" "lambda_iam_role" {
    name = "lambda_role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [           
      {
        Action = "sts:AssumeRole"    
        Effect = "Allow"             
        Principal = {
          Service = "lambda.amazonaws.com"   
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role = aws_iam_role.lambda_iam_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 
}


# Package the Lambda function code
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.js"
  output_path = "${path.module}/lambda/lambda.zip"
}


# API Gateway (HTTP)

resource "aws_apigatewayv2_api" "Http_api" {
    name = "http-api"
    protocol_type = "HTTP"
}


resource "aws_apigatewayv2_route" "post_example_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "POST /example"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}


# API Integartion with Lambda

resource "aws_apigatewayv2_integration" "lambda_integration" {
    api_id = aws_apigatewayv2_api.Http_api.id
    integration_type = "AWS_PROXY"
    integration_uri = aws_lambda_function.crud_lambda.invoke_arn
    integration_method = "POST"
    payload_format_version = "2.0"
}


 # Route (GET /example)
resource "aws_apigatewayv2_route" "get_example_route" {
  api_id    = aws_apigatewayv2_api.Http_api.id
  route_key = "GET /user"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda Permission for API Gateway
  resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crud_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.Http_api.execution_arn}/*"
}


# Deployment (Stage)

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.Http_api.id
  name        = "prod"
  auto_deploy = true
}


# Output API URL

output "api_invoke_url" {
  value = aws_apigatewayv2_api.Http_api.api_endpoint
}
     