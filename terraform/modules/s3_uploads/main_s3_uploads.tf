resource "aws_s3_object" "files" {
  for_each      = var.s3_files_map
  bucket        = var.s3_bucket_id
  key           = each.value.s3_key
  content_type  = each.value.content_type
  source        = each.value.source
}