output "glue_database_name" {
  description = "The generated Amazon Glue Catalog DB name"
  value = aws_glue_catalog_database.catalog_db.name
}

output "glue_crawler_name" {
  description = "The generated Glue Crawler name that scans the source s3 bucket under the hood"
  value = aws_glue_crawler.s3_crawler.name
}

output "athena_results_bucket" {
  description = "The target s3 bucket name that stores the Athena query results"
  value = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  description = "ARN of the Athena query results bucket"
  value       = aws_s3_bucket.athena_results.arn
}

output "athena_workgroup_name" {
  description = "The Athena Workgroup name that enforces the query result target location"
  value = aws_athena_workgroup.analytics_workgroup.name
}

