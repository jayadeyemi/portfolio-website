resource "aws_s3_object" "files" {
  for_each = var.s3_files_map

  bucket = var.s3_bucket_id
  key    = each.value.s3_key

  content = each.value.classification == "text" ? each.value.processed_content : null
  content_base64 = each.value.classification == "binary" ? each.value.processed_content : null
  content_type = each.value.content_type
}