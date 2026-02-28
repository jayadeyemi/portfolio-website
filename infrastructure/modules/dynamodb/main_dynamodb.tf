############################################################################################################
# DynamoDB Tables for Spotify Multi-User Architecture
# Cost optimization: PAY_PER_REQUEST (on-demand) — zero cost when idle
# Uses AWS-owned encryption (free) for table-level encryption
############################################################################################################

# Users table — maps internal user_id to Spotify account
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "spotify_user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "spotify-user-id-index"
    hash_key        = "spotify_user_id"
    projection_type = "ALL"
  }

  tags = {
    Name    = "${var.project_name}-users"
    Project = var.project_name
  }
}

# Spotify tokens table — encrypted refresh tokens per user
resource "aws_dynamodb_table" "spotify_tokens" {
  name         = "${var.project_name}-spotify-tokens"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = {
    Name    = "${var.project_name}-spotify-tokens"
    Project = var.project_name
  }
}

# Sessions table — server-side session metadata with TTL auto-cleanup
resource "aws_dynamodb_table" "sessions" {
  name         = "${var.project_name}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name    = "${var.project_name}-sessions"
    Project = var.project_name
  }
}

# Insights table — cached derived data per user with TTL
resource "aws_dynamodb_table" "insights" {
  name         = "${var.project_name}-insights"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "insight_key"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "insight_key"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name    = "${var.project_name}-insights"
    Project = var.project_name
  }
}

# Access requests table — tracks demo access request submissions
resource "aws_dynamodb_table" "access_requests" {
  name         = "${var.project_name}-access-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  tags = {
    Name    = "${var.project_name}-access-requests"
    Project = var.project_name
  }
}

# Play history table — app-recorded Spotify plays per user for playlist generation
resource "aws_dynamodb_table" "play_history" {
  name         = "${var.project_name}-play-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "played_at"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "played_at"
    type = "N"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name    = "${var.project_name}-play-history"
    Project = var.project_name
  }
}

############################################################################################################
# End of File
############################################################################################################
