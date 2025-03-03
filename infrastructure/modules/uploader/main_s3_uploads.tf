
resource "aws_s3_object" "files" {
  for_each = var.s3_files_map

  bucket = var.s3_bucket_id
  key    = each.value.s3_key

  content = var.s3_files_map[each.key] == "text" ? each.value.processed_content : null
  content_base64 = var.s3_files_map[each.key] == "binary" ? each.value.processed_content : null

  content_type = each.value.content_type
}