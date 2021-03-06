resource "aws_iam_role" "logging-scheduled-task-role" {
  count = "${var.logging-enabled}"
  name = "${var.Env-Name}-logging-scheduled-task-role"
  assume_role_policy = <<DOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
DOC
}

resource "aws_iam_role_policy" "logging-scheduled-task-policy" {
  count = "${var.logging-enabled}"
  name = "${var.Env-Name}-logging-scheduled-task-policy"
  role = "${aws_iam_role.logging-scheduled-task-role.id}"
  policy = <<DOC
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ecs:RunTask",
            "Resource": "${replace(aws_ecs_task_definition.logging-api-scheduled-task.arn, "/:\\d+$/", ":*")}"
        },
        {
          "Effect": "Allow",
          "Action": "iam:PassRole",
          "Resource": [
            "*"
          ],
          "Condition": {
            "StringLike": {
              "iam:PassedToService": "ecs-tasks.amazonaws.com"
            }
          }
        }
    ]
}
DOC
}

resource "aws_cloudwatch_event_target" "logging-publish-daily-statistics" {
  count     = "${var.logging-enabled}"
  target_id = "${var.Env-Name}-logging-daily-statistics"
  arn       = "${aws_ecs_cluster.api-cluster.arn}"
  rule      = "${aws_cloudwatch_event_rule.daily_statistics_logging_event.name}"
  role_arn  = "${aws_iam_role.logging-scheduled-task-role.arn}"

  ecs_target = {
    task_count = 1
    task_definition_arn = "${aws_ecs_task_definition.logging-api-scheduled-task.arn}"
    launch_type  = "EC2"
  }

  input = <<EOF
{
  "containerOverrides": [
    {
      "name": "logging",
      "command": ["bundle", "exec", "rake", "publish_daily_statistics"]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "logging-publish-weekly-statistics" {
  count     = "${var.logging-enabled}"
  target_id = "${var.Env-Name}-logging-weekly-statistics"
  arn       = "${aws_ecs_cluster.api-cluster.arn}"
  rule      = "${aws_cloudwatch_event_rule.weekly_statistics_logging_event.name}"
  role_arn  = "${aws_iam_role.logging-scheduled-task-role.arn}"

  ecs_target = {
    task_count = 1
    task_definition_arn = "${aws_ecs_task_definition.logging-api-scheduled-task.arn}"
  }

  input = <<EOF
{
  "containerOverrides": [
    {
      "name": "logging",
      "command": ["bundle", "exec", "rake", "publish_weekly_statistics"]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "logging-publish-monthly-statistics" {
  count     = "${var.logging-enabled}"
  target_id = "${var.Env-Name}-logging-monthly-statistics"
  arn       = "${aws_ecs_cluster.api-cluster.arn}"
  rule      = "${aws_cloudwatch_event_rule.monthly_statistics_logging_event.name}"
  role_arn  = "${aws_iam_role.logging-scheduled-task-role.arn}"

  ecs_target = {
    task_count = 1
    task_definition_arn = "${aws_ecs_task_definition.logging-api-scheduled-task.arn}"

    network_configuration = {
      security_groups = ["${var.backend-sg-list}"]
      subnets         = ["${var.subnet-ids}"]
    }
  }

  input = <<EOF
{
  "containerOverrides": [
    {
      "name": "logging",
      "command": ["bundle", "exec", "rake", "publish_monthly_statistics"]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "logging-daily-session-deletion" {
  target_id = "${var.Env-Name}-logging-daily-session-deletion"
  arn       = "${aws_ecs_cluster.api-cluster.arn}"
  rule      = "${aws_cloudwatch_event_rule.daily_session_deletion_event.name}"
  role_arn  = "${aws_iam_role.logging-scheduled-task-role.arn}"

  ecs_target = {
    task_count = 1
    task_definition_arn = "${aws_ecs_task_definition.logging-api-scheduled-task.arn}"

    network_configuration = {
      security_groups = ["${var.backend-sg-list}"]
      subnets         = ["${var.subnet-ids}"]
    }
  }

  input = <<EOF
{
  "containerOverrides": [
    {
      "name": "logging",
      "command": ["bundle", "exec", "rake", "daily_session_deletion"]
    }
  ]
}
EOF
}

resource "aws_ecs_task_definition" "logging-api-scheduled-task" {
  count = "${var.logging-enabled}"
  family   = "logging-api-scheduled-task-${var.Env-Name}"
  task_role_arn = "${aws_iam_role.logging-api-task-role.arn}"

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
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "hostname": null,
      "essential": true,
      "entryPoint": null,
      "mountPoints": [],
      "name": "logging",
      "ulimits": null,
      "dockerSecurityOptions": null,
      "environment": [
        {
          "name": "DB_NAME",
          "value": "govwifi_${var.Env-Name}"
        },{
          "name": "DB_PASS",
          "value": "${var.db-password}"
        },{
          "name": "DB_USER",
          "value": "${var.db-user}"
        },{
          "name": "DB_HOSTNAME",
          "value": "${var.db-hostname}"
        },{
          "name": "RACK_ENV",
          "value": "${var.rack-env}"
        },{
          "name": "SENTRY_DSN",
          "value": "${var.logging-sentry-dsn}"
        },{
          "name": "ENVIRONMENT_NAME",
          "value": "${var.Env-Name}"
        },{
          "name": "USER_SIGNUP_API_BASE_URL",
          "value": "${var.user-signup-api-base-url}"
        },{
          "name": "PERFORMANCE_URL",
          "value": "${var.performance-url}"
        },{
          "name": "PERFORMANCE_DATASET",
          "value": "${var.performance-dataset}"
        },{
          "name": "PERFORMANCE_BEARER_ACCOUNT_USAGE",
          "value": "${var.performance-bearer-account-usage}"
        },{
          "name": "PERFORMANCE_BEARER_UNIQUE_USERS",
          "value": "${var.performance-bearer-unique-users}"
        },{
          "name": "S3_PUBLISHED_LOCATIONS_IPS_BUCKET",
          "value": "govwifi-${var.rack-env}-admin"
        },{
          "name": "S3_PUBLISHED_LOCATIONS_IPS_OBJECT_KEY",
          "value": "ips-and-locations.json"
        }
      ],
      "links": null,
      "workingDirectory": null,
      "readonlyRootFilesystem": null,
      "image": "${var.logging-docker-image}",
      "command": null,
      "user": null,
      "dockerLabels": null,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.logging-api-log-group.name}",
          "awslogs-region": "${var.aws-region}",
          "awslogs-stream-prefix": "${var.Env-Name}-logging-api-docker-logs"
        }
      },
      "cpu": 0,
      "privileged": null,
      "expanded": true
    }
]
EOF
}
