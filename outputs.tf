output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion host"
  value       = aws_instance.bastion.public_ip
}

output "web_private_ips" {
  description = "Private IPs of the web servers"
  value       = { for k, v in aws_instance.web : k => v.private_ip }
}

output "db_private_ip" {
  description = "Private IP of the Database server"
  value       = aws_instance.db.private_ip
}
