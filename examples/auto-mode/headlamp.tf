# Headlamp: Cognito (SAML + hosted UI) → Pre Token Lambda (Entra groups → cognito:groups) → EKS OIDC + Secrets Manager for in-cluster Headlamp.
# Phase 1: apply without headlamp_saml_metadata_url → use outputs for IdP ACS/audience. Phase 2: set URL + headlamp_saml_provider_name, apply again.

locals {
  _headlamp_saml_primary     = var.headlamp_saml_metadata_url != null ? trimspace(var.headlamp_saml_metadata_url) : ""
  _headlamp_saml_legacy      = var.headlamp_idc_saml_metadata_url != null ? trimspace(var.headlamp_idc_saml_metadata_url) : ""
  headlamp_saml_metadata_url = local._headlamp_saml_primary != "" ? local._headlamp_saml_primary : local._headlamp_saml_legacy
  headlamp_saml_enabled      = local.headlamp_saml_metadata_url != ""
}

resource "aws_cognito_user_pool" "headlamp" {
  name = "${var.cluster_name}-headlamp"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  schema {
    name                     = "groups"
    attribute_data_type      = "String"
    mutable                  = true
    developer_only_attribute = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.headlamp_pre_token.arn
      lambda_version = "V2_0"
    }
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_domain" "headlamp" {
  domain       = "${var.cluster_name}-headlamp"
  user_pool_id = aws_cognito_user_pool.headlamp.id
}

resource "aws_cognito_identity_provider" "saml" {
  count = local.headlamp_saml_enabled ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.headlamp.id
  provider_name = var.headlamp_saml_provider_name
  provider_type = "SAML"

  provider_details = {
    MetadataURL = local.headlamp_saml_metadata_url
    IDPSignout  = "false"
  }

  attribute_mapping = {
    email           = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    username        = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"
    "custom:groups" = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
  }

  lifecycle {
    ignore_changes = [
      provider_details["ActiveEncryptionCertificate"],
      provider_details["SLORedirectBindingURI"],
      provider_details["SSORedirectBindingURI"],
    ]
  }
}

resource "aws_cognito_user_pool_client" "headlamp" {
  name         = "headlamp"
  user_pool_id = aws_cognito_user_pool.headlamp.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  callback_urls = concat(
    [for h in var.headlamp_hostnames : "https://${h}/oidc-callback"],
    [
      "http://localhost:4466/oidc-callback",
      "https://localhost:4466/oidc-callback",
      "http://127.0.0.1:4466/oidc-callback",
      "https://127.0.0.1:4466/oidc-callback",
    ],
  )

  logout_urls = concat(
    [for h in var.headlamp_hostnames : "https://${h}"],
    [
      "http://localhost:4466",
      "https://localhost:4466",
      "http://127.0.0.1:4466",
      "https://127.0.0.1:4466",
    ],
  )

  # Headlamp omits identity_provider= on /oauth2/authorize; COGNITO must be listed or SAML-only clients get HTTP 400.
  supported_identity_providers = local.headlamp_saml_enabled ? distinct(concat(["COGNITO"], [var.headlamp_saml_provider_name])) : ["COGNITO"]

  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_identity_provider.saml]
}

resource "aws_eks_identity_provider_config" "headlamp" {
  cluster_name = module.eks.cluster_name

  oidc {
    client_id                     = aws_cognito_user_pool_client.headlamp.id
    issuer_url                    = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.headlamp.id}"
    identity_provider_config_name = "cognito-headlamp"
    username_claim                = "sub"
    groups_claim                  = "cognito:groups"
  }

  tags = var.tags
}

resource "aws_secretsmanager_secret" "headlamp_oidc" {
  name                    = "headlamp/oidc"
  description             = "Headlamp OIDC credentials (Cognito) for Secrets Store CSI"
  recovery_window_in_days = 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "headlamp_oidc" {
  secret_id = aws_secretsmanager_secret.headlamp_oidc.id
  secret_string = jsonencode({
    OIDC_CLIENT_ID     = aws_cognito_user_pool_client.headlamp.id
    OIDC_CLIENT_SECRET = aws_cognito_user_pool_client.headlamp.client_secret
    OIDC_ISSUER_URL    = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.headlamp.id}"
    # Headlamp prepends openid; duplicate scope → Cognito 400.
    OIDC_SCOPES = "email,profile"
  })
}

data "archive_file" "headlamp_pre_token" {
  type        = "zip"
  output_path = "${path.module}/headlamp_pre_token.zip"
  source {
    content  = file("${path.module}/cognito_pre_token.js")
    filename = "cognito_pre_token.js"
  }
}

resource "aws_iam_role" "headlamp_pre_token_lambda" {
  name = "${var.cluster_name}-headlamp-pre-token-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "headlamp_pre_token_lambda_basic" {
  role       = aws_iam_role.headlamp_pre_token_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "headlamp_pre_token" {
  function_name    = "${var.cluster_name}-headlamp-pre-token"
  role             = aws_iam_role.headlamp_pre_token_lambda.arn
  runtime          = "nodejs24.x"
  handler          = "cognito_pre_token.handler"
  filename         = data.archive_file.headlamp_pre_token.output_path
  source_code_hash = data.archive_file.headlamp_pre_token.output_base64sha256

  environment {
    variables = {
      GROUP_RULES = jsonencode(var.headlamp_rbac_group_rules)
    }
  }

  tags = var.tags
}

resource "aws_lambda_permission" "headlamp_cognito_pre_token" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.headlamp_pre_token.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.headlamp.arn
}
