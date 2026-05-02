variable "aws_region" {
  default = "us-east-1"
}

variable "get_zip_path" {
  description = "Path to GET product bootstrap.zip"
  default     = "../target/lambda/rust-product-get/bootstrap.zip"
}

variable "post_zip_path" {
  description = "Path to POST product bootstrap.zip"
  default     = "../target/lambda/rust-product-post/bootstrap.zip"
}
