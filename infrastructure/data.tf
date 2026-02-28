data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${var.backend_path}${var.lambda_template}"
  output_path = local.lambda_zip_path
}

data "local_file" "files" {
  # use s3_file_list to get the list of files
  for_each = { for file in var.s3_file_list : file => file }
  filename = "${path.module}/${var.frontend_path}${each.value}"
}
