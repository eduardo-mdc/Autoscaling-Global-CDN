output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = aws_subnet.public[*].id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}
output "ecs_instance_sg_id" {
  value = aws_security_group.ecs_instances.id
}