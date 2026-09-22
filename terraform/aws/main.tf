terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "existing" {
  id = "vpc-040ba72e64469cbb4"
}

data "aws_subnet" "public_a" {
  id = "subnet-067546f07a8fef773"
}

data "aws_subnet" "public_b" {
  id = "subnet-00870fb0b8c5109d7"
}

data "aws_security_group" "alb" {
  id = "sg-0184438c289d0e122"
}

data "aws_security_group" "ecs" {
  id = "sg-00180ac807839979d"
}

data "aws_ecs_cluster" "existing" {
  cluster_name = "aws-devops-platform-dev-cluster"
}

data "aws_lb" "existing" {
  name = "aws-devops-platform-dev-alb"
}

data "aws_iam_role" "execution" {
  name = "aws-devops-platform-dev-ecs-execution-role"
}

data "aws_iam_role" "task" {
  name = "aws-devops-platform-dev-ecs-task-role"
}

resource "aws_ecr_repository" "capstone" {
  name                 = var.project_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "capstone" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "capstone" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = data.aws_iam_role.execution.arn
  task_role_arn      = data.aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name       = "app"
      image      = "${aws_ecr_repository.capstone.repository_url}:${var.image_tag}"
      essential  = true
      privileged = false

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_ENV"
          value = "production"
        },
        {
          name  = "CLOUD_PROVIDER"
          value = "aws"
        },
        {
          name  = "APP_VERSION"
          value = var.image_tag
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.capstone.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

resource "aws_lb_target_group" "capstone" {
  name        = "multi-cloud-capstone-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "capstone" {
  load_balancer_arn = data.aws_lb.existing.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.capstone.arn
  }
}

resource "aws_vpc_security_group_ingress_rule" "capstone_listener" {
  security_group_id = data.aws_security_group.alb.id

  description = "Capstone HTTP listener"
  from_port   = var.listener_port
  to_port     = var.listener_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_ecs_service" "capstone" {
  name            = "${var.project_name}-service"
  cluster         = data.aws_ecs_cluster.existing.arn
  task_definition = aws_ecs_task_definition.capstone.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      data.aws_subnet.public_a.id,
      data.aws_subnet.public_b.id
    ]

    security_groups  = [data.aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.capstone.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.capstone,
    aws_vpc_security_group_ingress_rule.capstone_listener
  ]
}
