## AWS IAM Access Token Secret can be parsed from Terraform.state
## terraform state pull | jq '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes'

output "nextcloud-s3-user_secret" {
  value     = aws_iam_access_key.nextcloud-s3-user.secret
  sensitive = true
}

output "nextcloud-s3-user_access_token" {
  value = aws_iam_access_key.nextcloud-s3-user.id
}

output "nextcloud01_eip" {
  value = aws_eip.nextcloud01_eip.public_ip
}
