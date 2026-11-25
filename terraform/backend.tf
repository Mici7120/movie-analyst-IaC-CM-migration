terraform {
  backend "s3" {
    bucket         = "terraform-state-458"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}
