output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.staging_web-server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.staging_web-server-eip.public_ip
}
