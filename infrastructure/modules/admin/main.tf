resource "aws_key_pair" "admin_key" {
  key_name   = "${var.resource_group_name}-admin"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_security_group" "admin_sg" {
  name        = "${var.resource_group_name}-admin-sg"
  description = "Allow SSH to admin host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.resource_group_name}-admin" }, var.tags)
}

data "aws_iam_policy_document" "admin_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "admin_role" {
  name               = "${var.resource_group_name}-admin-role"
  assume_role_policy = data.aws_iam_policy_document.admin_assume.json
}

resource "aws_iam_role_policy_attachment" "admin_ec2_full" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_instance_profile" "admin_profile" {
  name = "${var.resource_group_name}-admin-profile"
  role = aws_iam_role.admin_role.name
}

data "aws_ami" "linux2" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "admin" {
  ami                         = data.aws_ami.linux2.id
  instance_type               = "t2.micro"
  subnet_id                   = var.subnet_id
  key_name                    = aws_key_pair.admin_key.key_name
  vpc_security_group_ids      = [aws_security_group.admin_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.admin_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker unzip curl
    usermod -aG docker ${var.admin_username}
    systemctl enable docker && systemctl start docker
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip && ./aws/install
    curl "https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest" -o /usr/local/bin/ecs-cli
    chmod +x /usr/local/bin/ecs-cli
    cat << 'SCRIPT' > /home/${var.admin_username}/manage-container-apps.sh
    #!/bin/bash
    echo "Manage container apps placeholder"
    SCRIPT
    chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/manage-container-apps.sh
    chmod +x /home/${var.admin_username}/manage-container-apps.sh
  EOF

  tags = merge({ Name = "${var.resource_group_name}-admin" }, var.tags)
}

resource "aws_eip" "admin_ip" {
  instance = aws_instance.admin.id
  vpc      = true
}
