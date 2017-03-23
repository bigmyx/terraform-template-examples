variable "name" {}
variable "instance_type" {}
variable "image_id" {}
variable "iam_instance_profile" {}
variable "user_data" {}
variable "key_name" {}
variable "volume_size" {}
variable "subnets" {
  type = "list"
}
variable "security_groups" {
  type = "list"
}
variable "min_size" {}
variable "max_size" {}

resource "aws_launch_configuration" "app" {
  name = "${var.name}"
  instance_type = "${var.instance_type}"
  image_id = "${var.image_id}"
  iam_instance_profile = "${var.iam_instance_profile}"
  security_groups = "${var.security_groups}"
  user_data = "${var.user_data}"
  key_name = "${var.key_name}"
  ebs_block_device = {
    device_name = "/dev/sdg"
    volume_size = "${var.volume_size}"
    volume_type = "gp2"
    delete_on_termination = true
  }
}

resource "aws_autoscaling_group" "app" {
  name = "${var.name}"
  vpc_zone_identifier = "${var.subnets}"
  min_size = "${var.min_size}"
  max_size = "${var.max_size}"
  desired_capacity = "${var.min_size}"
  launch_configuration = "${aws_launch_configuration.app.name}"
  health_check_type = "EC2"
  tag {
    key = "Name"
    value = "${var.name}"
    propagate_at_launch = "true"
  }
  #lifecycle {
  #  create_before_destroy = true
  #}
}
