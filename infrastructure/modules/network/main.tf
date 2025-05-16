// Create a VPC + 2 public subnets + IGW + RT + SG for HTTP
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.resource_group_name}-vpc" }
}

data "aws_availability_zones" "azs" {}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  tags = { Name = "${var.resource_group_name}-public-${count.index+1}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.resource_group_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.resource_group_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${var.resource_group_name}-alb-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow HTTP"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.resource_group_name}-alb-sg" }
}

resource "aws_security_group" "ecs_instances" {
  name        = "${var.resource_group_name}-ecs-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow ALB + bastion to talk to ECS hosts"

  # allow SSH from the bastion SG
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [ aws_security_group.alb.id ]
  }

  # allow SSH from the admin SG
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [ var.admin_sg_id ]
  }

  # allowing ALB healthchecks / traffic
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [ aws_security_group.alb.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.resource_group_name}-ecs-sg" }
}


