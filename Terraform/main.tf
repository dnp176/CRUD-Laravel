terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 0. SSH Key Generation ---

resource "tls_private_key" "rsa_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "laravel-ecs-key"
  public_key = tls_private_key.rsa_key.public_key_openssh
  tags       = { Name = "Laravel-Key-Pair" }
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa_key.private_key_pem
  filename = "laravel-key.pem"
}

# --- 1. VPC & Networking ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "Laravel-VPC" }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "Laravel-Public-Subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "Laravel-Public-Subnet-2" }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "Laravel-Private-Subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "Laravel-Private-Subnet-2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "Laravel-IGW" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "Laravel-NAT-EIP" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  tags = { Name = "Laravel-NAT-Gateway" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Laravel-Public-RT" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "Laravel-Private-RT" }
}

resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "priv_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "priv_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# --- 2. Security Groups ---

resource "aws_security_group" "alb_sg" {
  name        = "ALB-SG"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

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
  tags = { Name = "Laravel-ALB-SG" }
}

resource "aws_security_group" "ecs_sg" {
  name        = "ECS-SG"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "Laravel-ECS-Nodes-SG" }
}

resource "aws_security_group" "rds_sg" {
  name        = "RDS-SG"
  description = "Allow MySQL from ECS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }
  tags = { Name = "Laravel-RDS-SG" }
}

# --- 3. RDS Database ---

resource "aws_db_subnet_group" "default" {
  name       = "laravel-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags       = { Name = "Laravel-DB-Subnet-Group" }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "laravel_app"
  username               = "laraveluser"
  password               = "CBDJZ80WGaiEnJZr" 
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  
  tags = { Name = "Laravel-MySQL-Instance" }
}

# --- 4. ECS Cluster & Infrastructure (EC2) ---

resource "aws_ecs_cluster" "main" {
  name = "Laravel-Cluster"
  tags = { Name = "Laravel-ECS-Cluster" }
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole_Custom"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = { Name = "Laravel-ECS-Instance-Role" }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile_Custom"
  role = aws_iam_role.ecs_instance_role.name
  tags = { Name = "Laravel-ECS-Instance-Profile" }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ecs-template"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  
  # UPDATED: Upgraded to t3.small (2GB RAM) for better stability
  instance_type = "t3.small" 
  
  key_name      = aws_key_pair.deployer.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_sg.id]

  # UPDATED: Adding tags to instances created by this template
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Laravel-ECS-Node"
      Project = "Laravel-Migration"
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
              EOF
  )
  
  tags = { Name = "Laravel-Launch-Template" }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-asg"
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }
  
  # UPDATED: Increased capacity limits
  min_size         = 3
  max_size         = 4
  desired_capacity = 3

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ecs_cp" {
  name = "laravel-capacity-provider" 

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
  tags = { Name = "Laravel-Capacity-Provider" }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_cp.name]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
  }
}

# --- 5. Application Load Balancer ---

resource "aws_lb" "main" {
  name               = "laravel-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  tags               = { Name = "Laravel-ALB" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Not Found"
      status_code  = "404"
    }
  }
  tags = { Name = "Laravel-HTTP-Listener" }
}

resource "aws_lb_target_group" "dev" {
  name     = "laravel-app1-dev-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
  }
  tags = { Name = "Laravel-Dev-TG" }
}

resource "aws_lb_target_group" "staging" {
  name     = "laravel-app2-stg-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
  }
  tags = { Name = "Laravel-Staging-TG" }
}

resource "aws_lb_target_group" "prod" {
  name     = "laravel-app3-prod-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
  }
  tags = { Name = "Laravel-Prod-TG" }
}

resource "aws_lb_listener_rule" "dev" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev.arn
  }

  condition {
    host_header {
      values = ["app1.local"]
    }
  }
  tags = { Name = "Rule-Dev-App" }
}

resource "aws_lb_listener_rule" "staging" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.staging.arn
  }

  condition {
    host_header {
      values = ["app2.local"]
    }
  }
  tags = { Name = "Rule-Staging-App" }
}

resource "aws_lb_listener_rule" "prod" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod.arn
  }

  condition {
    host_header {
      values = ["app3.local"]
    }
  }
  tags = { Name = "Rule-Prod-App" }
}

# --- 6. ECS Task Definitions & Services ---

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole_Custom"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = { Name = "Laravel-ECS-Task-Exec-Role" }
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# -- APP 1: Development --
resource "aws_ecs_task_definition" "app1_dev" {
  family                   = "laravel-app1-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  tags                     = { Name = "Task-Def-Dev", Environment = "Development" }

  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = "dnptestaccount/laravel-db-based-app:development"
      cpu       = 256
      memory    = 512
      essential = true
      command   = ["/bin/sh", "-c", "php artisan migrate --force && apache2-foreground"], 
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_NAME", value = "Development" },
        { name = "APP_ENV", value = "local" },
        { name = "APP_KEY", value = "base64:RCcvtRifNVs627Ha8IDHo7rJQJkZm9J+YgHElJEBPcw=" },
        { name = "APP_DEBUG", value = "true" },
        { name = "APP_URL", value = "http://app1.local" },
        { name = "LOG_CHANNEL", value = "stack" },
        { name = "DB_CONNECTION", value = "mysql" },
        { name = "DB_HOST", value = aws_db_instance.default.address },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_DATABASE", value = "laravel_app" },
        { name = "DB_USERNAME", value = "laraveluser" },
        { name = "DB_PASSWORD", value = "CBDJZ80WGaiEnJZr" }
      ]
    }
  ])
}

resource "aws_ecs_service" "app1_dev" {
  name            = "laravel-app1-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app1_dev.arn
  desired_count   = 1
  tags            = { Name = "Service-Dev" }
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 100
  }

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dev.arn
    container_name   = "laravel-app"
    container_port   = 80
  }
}

# -- APP 2: Staging --
resource "aws_ecs_task_definition" "app2_stg" {
  family                   = "laravel-app2-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  tags                     = { Name = "Task-Def-Staging", Environment = "Staging" }

  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = "dnptestaccount/laravel-db-based-app:staging" 
      cpu       = 256
      memory    = 512
      essential = true
      command   = ["/bin/sh", "-c", "php artisan migrate --force && apache2-foreground"],
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_NAME", value = "Staging" },
        { name = "APP_ENV", value = "staging" },
        { name = "APP_KEY", value = "base64:RCcvtRifNVs627Ha8IDHo7rJQJkZm9J+YgHElJEBPcw=" },
        { name = "APP_DEBUG", value = "true" },
        { name = "APP_URL", value = "http://app2.local" },
        { name = "DB_CONNECTION", value = "mysql" },
        { name = "DB_HOST", value = aws_db_instance.default.address },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_DATABASE", value = "laravel_app" },
        { name = "DB_USERNAME", value = "laraveluser" },
        { name = "DB_PASSWORD", value = "CBDJZ80WGaiEnJZr" }
      ]
    }
  ])
}

resource "aws_ecs_service" "app2_stg" {
  name            = "laravel-app2-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app2_stg.arn
  desired_count   = 1
  tags            = { Name = "Service-Staging" }
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 100
  }

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.staging.arn
    container_name   = "laravel-app"
    container_port   = 80
  }
}

# -- APP 3: Production --
resource "aws_ecs_task_definition" "app3_prod" {
  family                   = "laravel-app3-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  tags                     = { Name = "Task-Def-Prod", Environment = "Production" }

  container_definitions = jsonencode([
    {
      name      = "laravel-app"
      image     = "dnptestaccount/laravel-db-based-app:production" 
      cpu       = 256
      memory    = 512
      essential = true
      command   = ["/bin/sh", "-c", "php artisan migrate --force && apache2-foreground"],
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_NAME", value = "Production" },
        { name = "APP_ENV", value = "production" },
        { name = "APP_KEY", value = "base64:RCcvtRifNVs627Ha8IDHo7rJQJkZm9J+YgHElJEBPcw=" },
        { name = "APP_DEBUG", value = "false" },
        { name = "APP_URL", value = "http://app3.local" },
        { name = "DB_CONNECTION", value = "mysql" },
        { name = "DB_HOST", value = aws_db_instance.default.address },
        { name = "DB_PORT", value = "3306" },
        { name = "DB_DATABASE", value = "laravel_app" },
        { name = "DB_USERNAME", value = "laraveluser" },
        { name = "DB_PASSWORD", value = "CBDJZ80WGaiEnJZr" }
      ]
    }
  ])
}

resource "aws_ecs_service" "app3_prod" {
  name            = "laravel-app3-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app3_prod.arn
  desired_count   = 1
  tags            = { Name = "Service-Prod" }
  
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_cp.name
    weight            = 100
  }

  network_configuration {
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prod.arn
    container_name   = "laravel-app"
    container_port   = 80
  }
}

# --- Outputs ---

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name to map in hosts file for app1.local, app2.local, etc."
}

output "private_key_file" {
  value       = local_file.private_key.filename
  description = "This is the name of your generated private key file."
}


# --- 7. OIDC Provider & CI/CD Roles (NO ACCESS KEYS) ---

# 1. GitHub OIDC Provider banayenge (One time setup per AWS Account)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"] 
}

# 2. IAM Role for Development Environment
resource "aws_iam_role" "github_actions_dev" {
  name = "GitHubActions-Laravel-Dev-Role"

  # Trust Policy: Sirf tumhare Repo aur Environment ko allow karega
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            # YE LINE SABSE IMPORTANT HAI: Sirf tumhara repo + development env
            "token.actions.githubusercontent.com:sub": "repo:dnp176/CRUD-Laravel:environment:development",
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = { Name = "GitHub-Actions-Dev-Role" }
}

# 3. Policy: Role ko kya permission milegi? (ECR push + ECS Update)
resource "aws_iam_policy" "cicd_policy" {
  name        = "Laravel-CICD-Policy"
  description = "Allow ECR push and ECS service update"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Docker Image Push karne ke liye permissions
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*" # Production me specific ECR ARN dena behtar hai
      },
      {
        # ECS Service update karne ke liye
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        # Task Definition me IAM PassRole (taki ECS task run kar sake)
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
            aws_iam_role.ecs_task_execution_role.arn,
            aws_iam_role.ecs_instance_role.arn
        ]
      }
    ]
  })
}

# 4. Role aur Policy ko jodna
resource "aws_iam_role_policy_attachment" "attach_cicd_dev" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = aws_iam_policy.cicd_policy.arn
}

# --- Output for GitHub Secrets ---
output "dev_role_arn" {
  value = aws_iam_role.github_actions_dev.arn
  description = "Is ARN ko GitHub Environment Secret me 'AWS_ROLE_ARN' ke naam se save karo"
}
