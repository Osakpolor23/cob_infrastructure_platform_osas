region       = "us-east-1"
project_name = "cob"
environment  = "dev"
vpc_cidr     = "10.0.0.0/16"

public_subnets = {
  "public-a" = { cidr_block = "10.0.0.0/24" }
  "public-b" = { cidr_block = "10.0.1.0/24" }
}

private_subnets = {
  "private-a" = { cidr_block = "10.0.10.0/24" }
  "private-b" = { cidr_block = "10.0.11.0/24" }
}

database_subnets = {
  "database-a" = { cidr_block = "10.0.20.0/24" }
  "database-b" = { cidr_block = "10.0.21.0/24" }
}

ingress_rules = [
  {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

bucket_name = "s3-bucket"

iam_group = "analysts"

iam_users = {
  "John-analyst" = {
    groups         = ["cob-dev-analysts"]
    console_access = true
  },
  "Richard-analyst" = {
    groups         = ["cob-dev-analysts"]
    console_access = true
  },
  "Jane-analyst" = {
    groups         = ["cob-dev-analysts"]
    console_access = true
  }
}
