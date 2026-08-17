output "bucket_name" {
  value = aws_s3_bucket.spa.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.spa.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.spa.id
}

output "bucket_arn" {
  value = aws_s3_bucket.spa.arn
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.spa.arn
}
