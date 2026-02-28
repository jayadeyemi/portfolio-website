output "invalidation_id" {
  description = "The ID of the terraform_data resource tracking the last invalidation"
  value       = terraform_data.cloudfront_invalidation.id
}
