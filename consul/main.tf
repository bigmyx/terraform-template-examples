
provider "aws" {
  region = "${var.region}"
}

###### Create IAM Role for Consul Instances #####
resource "aws_iam_role" "ec2" {
  name = "${var.iam_role}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "${var.iam_profile}"
  roles = ["${aws_iam_role.ec2.name}"]
}

resource "aws_iam_policy_attachment" "read_for_ec2" {
  name = "read-only-for-ec2-tf"
  roles = ["${aws_iam_role.ec2.id}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

###### Create ELB for Consul Instances #####
resource "aws_elb" "consul_elb_tf" {
  name = "consul-elb-tf"
  internal = "true"
  cross_zone_load_balancing = "true"
  subnets = ["${lookup(var.subnet, "a")}", "${lookup(var.subnet, "b")}"]
  security_groups = ["${var.security_group}"]
  listener {
    instance_port     = 8500
    instance_protocol = "http"
    lb_port           = 8500
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:8500/v1/health/service/consul"
    interval = 10
  }
}

##### Create Route53 DNS Record for ELB's endpoint #####
resource "aws_route53_record" "consul_dns_tf" {
  zone_id = "${lookup(var.route53_zone_id, var.environment)}"
  name = "${lookup(var.dns_name, var.environment)}"
  type = "CNAME"
  ttl = "300"
  records = ["${aws_elb.consul_elb_tf.dns_name}"]
 }

###### Create ASG for Consul Instances #####
resource "aws_autoscaling_group" "consul_asg_tf" {
  name                 = "consul-asg-tf"
  availability_zones   = "${var.zones}"
  vpc_zone_identifier  = ["${lookup(var.subnet, "a")}, ${lookup(var.subnet, "b")}"]
  min_size             = "${var.num_instances}"
  max_size             = "${var.num_instances}"
  desired_capacity     = "${var.num_instances}"
  min_elb_capacity     = "${var.num_instances}"
  launch_configuration = "${aws_launch_configuration.consul_lc_tf.name}"
  load_balancers       = ["${aws_elb.consul_elb_tf.name}"]
  depends_on           = ["aws_iam_policy_attachment.read_for_ec2"]
  tag {
    key                 = "Name"
    value               = "${var.name_tag}"
    propagate_at_launch = "true"
  }
}

data "template_file" "provision" {
  template = "${file("provision.tpl")}"
  vars {
    region = "${var.region}"
    tag = "${var.name_tag}"
    consul_version = "${var.consul_version}"
  }
}

resource "aws_launch_configuration" "consul_lc_tf" {
  instance_type = "${var.size}"
  image_id  = "${var.ami}"
  name = "consul-lc-tf"
  iam_instance_profile = "arn:aws:iam::969968648862:instance-profile/${var.iam_profile}"
  security_groups = ["${var.security_group}"]
  user_data       = "${data.template_file.provision.rendered}"
  key_name = "${lookup(var.keypair, var.environment)}"

  root_block_device {
      volume_type = "gp2"
      volume_size = 10
  }
}

output "consul-elb-endpoint" {
  value = "${aws_elb.consul_elb_tf.dns_name}"
}
