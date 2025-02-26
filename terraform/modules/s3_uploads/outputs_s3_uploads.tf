# 3. Output the object key or anything else needed
output "uploaded_keys" {
  description = "The S3 object key for the uploaded JS file"
  value       = aws_s3_object.files[*].key
}