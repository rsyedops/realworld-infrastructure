output "instance_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "endpoint" {
  description = "Connection endpoint, host and port."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname of the instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port the instance listens on."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "security_group_id" {
  description = "Security group guarding the instance."
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the RDS-managed master credentials."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "kms_key_arn" {
  description = "KMS key encrypting storage, snapshots and the master secret."
  value       = aws_kms_key.storage.arn
}
