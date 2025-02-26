################################################################################
# Terraform Variables
################################################################################
# Region Variables
aws_region = "us-east-2"   # e.g. "us-east-1"

# Profile Variables
project_name                = "portfolio"
website_domain_name         = ""   # e.g. "example.com"
secrets_manager_secret_name = "credentials"

# Secrets Manager Variables
spotify_client_id       = "spotify_client_id"
spotify_client_secret   = "spotify_client_secret"
lambda_runtime          = "python3.8"
cloudfront_price_class  = "PriceClass_100"

# Local paths and configurations
frontend_path       = "../app/"
lambda_path         = "../lambda/"
lambda_filename     = "lambda_function.zip"
home_html           = "index.html"
home_css            = "styles.css"
spotify_html        = "myspotify/index.html"
spotify_css         = "myspotify/styles.css"
spotify_js          = "myspotify/main.js"
spotify_js_template = "myspotify/main.js.tmpl"
################################################################################
# End of File
################################################################################