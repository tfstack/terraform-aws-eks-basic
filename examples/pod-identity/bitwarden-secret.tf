# # AWS Secrets Manager secret for Bitwarden sm-operator machine token
# # SecretProviderClass expects: bitwarden/sm-operator/machine-token with {"token":"<value>"}
# resource "aws_secretsmanager_secret" "bitwarden_sm_token" {
#   name        = "bitwarden/sm-operator/atlantis-1/machine-token"
#   description = "Bitwarden Secrets Manager machine token for sm-operator (atlantis-1)"
#   tags        = var.tags
# }

# resource "aws_secretsmanager_secret_version" "bitwarden_sm_token" {
#   secret_id = aws_secretsmanager_secret.bitwarden_sm_token.id
#   secret_string = jsonencode({
#     token = var.bitwarden_sm_machine_token
#   })
# }
