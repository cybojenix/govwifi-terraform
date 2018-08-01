resource "aws_ecs_cluster" "admin-cluster" {
  name = "${var.Env-Name}-admin-cluster"
}

resource "aws_cloudwatch_log_group" "admin-log-group" {
  name = "${var.Env-Name}-admin-log-group"

  retention_in_days = 90
}

resource "aws_ecr_repository" "govwifi-admin-ecr" {
  count = "${var.ecr-repository-count}"
  name  = "govwifi/admin"
}

resource "aws_ecs_task_definition" "admin-task" {
  family = "allowed-sites-api-task-${var.Env-Name}"

  container_definitions = <<EOF
[
    {
      "volumesFrom": [],
      "memory": 950,
      "extraHosts": null,
      "dnsServers": null,
      "disableNetworking": null,
      "dnsSearchDomains": null,
      "portMappings": [
        {
          "hostPort": 0,
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "hostname": null,
      "essential": true,
      "entryPoint": null,
      "mountPoints": [],
      "name": "admin",
      "ulimits": null,
      "dockerSecurityOptions": null,
      "environment": [
        {
          "name": "RACK_ENV",
          "value": "${var.rack-env}"
        },{
          "name": "SECRET_KEY_BASE",
          "value": "${var.secret-key-base}"
        }
      ],
      "links": null,
      "workingDirectory": null,
      "readonlyRootFilesystem": null,
      "image": "${var.admin-docker-image}",
      "command": null,
      "user": null,
      "dockerLabels": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.admin-log-group.name}",
          "awslogs-region": "${var.aws-region}",
          "awslogs-stream-prefix": "${var.Env-Name}-admin-docker-logs"
        }
      },
      "cpu": 0,
      "privileged": null,
      "expanded": true
    }
]
EOF
}

resource "aws_ecs_service" "admin-service" {
  depends_on      = ["aws_alb_listener.alb_listener"]
  name            = "admin-${var.Env-Name}"
  cluster         = "${aws_ecs_cluster.admin-cluster.id}"
  task_definition = "${aws_ecs_task_definition.admin-task.arn}"
  desired_count   = "${var.instance-count}"
  iam_role        = "${var.ecs-service-role}"

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.admin-tg.arn}"
    container_name = "admin"
    container_port = "3000"
  }
}


resource "aws_alb_target_group" "admin-tg" {
  depends_on   = ["aws_lb.admin-alb"]
  name     = "admin-${var.Env-Name}"
  port     = "3000"
  protocol = "HTTP"
  vpc_id   = "${var.vpc-id}"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/healthcheck"
  }
}