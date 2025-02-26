resource "aws_s3_object" "files" {
  for_each     = var.s3_files
  bucket       = var.s3_bucket_id
  key          = each.value.s3_key
  content_type = each.value.content_type

  source = substr(trimspace(each.value.source), 0, 9) != "<!DOCTYPE" ? each.value.source : null
  content = substr(trimspace(each.value.source), 0, 9) == "<!DOCTYPE" ? each.value.source : null
}