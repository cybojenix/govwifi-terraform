resource "aws_autoscaling_group" "ecs-admin-cluster" {
  vpc_zone_identifier       = ["${var.subnet-ids}"]
  name                      = "${var.Env-Name}-admin-cluster"
  min_size                  = "${var.min-size}"
  max_size                  = "10"
  desired_capacity          = "${var.instance-count}"
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.ecs.name}"
  health_check_grace_period = "${var.health_check_grace_period}"
  enabled_metrics           = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Env"
    value               = "${var.Env-Name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${title(var.Env-Name)} Admin"
    propagate_at_launch = true
  }
}
