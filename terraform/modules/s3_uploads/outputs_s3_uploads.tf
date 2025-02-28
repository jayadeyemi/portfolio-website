# 3. Output the object key or anything else needed
output "uploaded_keys" {
  description = "The S3 object key for the uploaded JS file"
  value       = { for k, v in var.s3_files_map : k => v.s3_key }
}