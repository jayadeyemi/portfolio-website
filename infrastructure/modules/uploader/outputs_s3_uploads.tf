# 3. Output the object key or anything else needed
output "uploaded_keys" {
  description = "The S3 object keys passed to the module"
  value       = [for file, details in var.s3_files_map : details.s3_key]
}