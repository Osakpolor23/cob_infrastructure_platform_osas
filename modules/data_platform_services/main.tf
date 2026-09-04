data "aws_s3_objects" "top_level_folders" {
  bucket    = var.data_bucket_name
  delimiter = "/"
}

resource "aws_glue_catalog_database" "catalog_db" {
  name        = lower(replace("${local.resource_name}_catalog_db", "-", "_"))
  description = "Glue Data Catalog database for ${var.project_name} analytics"
}

resource "aws_glue_crawler" "s3_crawler" {
  name          = "${local.resource_name}-s3-crawler"
  role          = var.glue_crawler_role_arn
  database_name = aws_glue_catalog_database.catalog_db.name

  dynamic "s3_target" {
    for_each = data.aws_s3_objects.top_level_folders.common_prefixes
    content {
      path = "s3://${var.data_bucket_name}/${s3_target.value}"
    }
  }

  schedule = var.crawler_schedule

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "athena_results" {
  bucket = lower("${local.resource_name}-athena-results-${random_string.suffix.result}")

  tags = {
    Name = "${local.resource_name}-athena-results"
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results_block" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results_lifecycle" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    expiration {
      days = var.query_results_retention_days
    }
  }
}

resource "aws_athena_workgroup" "analytics_workgroup" {
  name = "${local.resource_name}-analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}