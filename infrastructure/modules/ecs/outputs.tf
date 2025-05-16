output "cluster_id"    { value = aws_ecs_cluster.this.id }
output "cluster_arn"   { value = aws_ecs_cluster.this.arn }
output "service_arn"   { value = aws_ecs_service.app.id }
output "alb_dns_name"  { value = aws_lb.alb.dns_name }
output "tg_arn"        { value = aws_lb_target_group.tg.arn }
