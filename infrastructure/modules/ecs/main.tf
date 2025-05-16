// ECS cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.resource_group_name}-cluster"
}

// EC2 Launch Template
data "aws_ami" "ecs_optimized" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}


resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.resource_group_name}-lt-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t2.micro"
  key_name      = var.admin_key_name
  user_data     = base64encode(<<-EOF
                        #!/bin/bash
                    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
                    EOF
  )
  vpc_security_group_ids = [
    var.alb_sg_id,
    var.instance_sg_id
  ]
}

// Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_replicas
  max_size            = var.max_replicas
  desired_capacity    = var.min_replicas
  tag {
    key                 = "Name"
    value               = "${var.resource_group_name}-instance"
    propagate_at_launch = true
  }
}

// IAM Role for Task Execution
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "task_exec" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
  name               = "${var.resource_group_name}-${var.region_name}-ecs-exec-role"
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.resource_group_name}-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = tostring(var.cpu * 1024)
  memory                   = tostring(var.memory * 1024)
  execution_role_arn       = aws_iam_role.task_exec.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "nginx:latest"
    cpu       = var.cpu * 1024
    memory    = var.memory * 1024
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 0
      protocol      = "tcp"
    }]
  }])
}

// ALB + TG + Listener
resource "aws_lb" "alb" {
  name               = "${var.resource_group_name}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.resource_group_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

// ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.resource_group_name}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.min_replicas
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

// Auto Scaling by Request Count
resource "aws_appautoscaling_target" "svc" {
  max_capacity       = var.max_replicas
  min_capacity       = var.min_replicas
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scale_req" {
  name               = "${var.resource_group_name}-scale"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.svc.resource_id
  scalable_dimension = aws_appautoscaling_target.svc.scalable_dimension
  service_namespace  = aws_appautoscaling_target.svc.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label = "${replace(aws_lb.alb.arn_suffix, "loadbalancer/", "")}/${aws_lb_target_group.tg.arn_suffix}"
    }

    target_value       = var.request_count_threshold
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
