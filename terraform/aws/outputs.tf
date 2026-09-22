output "ecr_repository_url" {
  value = aws_ecr_repository.capstone.repository_url
}

output "alb_dns_name" {
  value = data.aws_lb.existing.dns_name
}

output "application_url" {
  value = "http://${data.aws_lb.existing.dns_name}:${var.listener_port}"
}
