variable "cluster_name" {}
variable "cert_bucket" {}


resource "aws_iam_role" "ecs_service" {
  name = "${format("%s-ecs-role", var.cluster_name)}"
  assume_role_policy = "${file("${path.module}/ecs-assume-role.json")}"
}

resource "aws_iam_role_policy" "ecs_service" {
  name = "${format("%s-ecs-policy", var.cluster_name)}"
  role = "${aws_iam_role.ecs_service.name}"
  policy = "${file("${path.module}/ecs-policy.json")}"
}

resource "aws_iam_instance_profile" "app" {
  name  = "${format("%s-ecs-profile", var.cluster_name)}"
  roles = ["${aws_iam_role.app_instance.name}"]
}

resource "aws_iam_role" "app_instance" {
  name = "${format("%s-ecs-instance-role", var.cluster_name)}"
  assume_role_policy = "${file("${path.module}/ec2-assume-role.json")}"
}

data "template_file" "instance_profile" {
  template = "${file("${path.module}/profile-policy.json")}"
  vars {
    cert_bucket = "${var.cert_bucket}"
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${format("%s-ecs-instance-policy", var.cluster_name)}"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

resource "aws_iam_role" "ecs_autoscale_role" {
  name               = "ecsAutoscaleRole"
  assume_role_policy = "${file("${path.module}/autoscale-assume-role.json")}"
}

resource "aws_iam_policy_attachment" "ecs_autoscale_role_attach" {
  name       = "ecs-autoscale-role-attach"
  roles      = ["${aws_iam_role.ecs_autoscale_role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

output "ecs_service_role_name" {
 value = "${aws_iam_role.ecs_service.name}"
}

output "aws_instance_profile_name" {
 value = "${aws_iam_instance_profile.app.name}"
}
