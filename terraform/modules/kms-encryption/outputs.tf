output "key_id" {
  description = "The globally unique identifier for the key"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.this.arn
}

output "key_alias" {
  description = "The display name of the alias"
  value       = aws_kms_alias.this.name
}

output "key_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the key alias"
  value       = aws_kms_alias.this.arn
}

output "key_policy" {
  description = "The IAM policy document for the key"
  value       = aws_kms_key.this.policy
  sensitive   = true
}

output "key_rotation_enabled" {
  description = "Whether key rotation is enabled"
  value       = aws_kms_key.this.enable_key_rotation
}

output "key_is_enabled" {
  description = "Whether the KMS key is enabled"
  value       = aws_kms_key.this.is_enabled
}
