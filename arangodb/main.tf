provider "aws" {
  region = "${var.region}"
}

############ IAM CONFIG ############
resource "aws_iam_role" "arango_ecs_elb" {
  count = "${lookup(var.create_iam_role, var.az)}"
  name = "${var.iam_role_name}"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "arango_ecs_elb" {
  count = "${lookup(var.create_iam_role, var.az)}"
  name = "${var.iam_role_name}"
  roles = ["${aws_iam_role.arango_ecs_elb.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}
############ IAM CONFIG END ############


############ ECS CLUSTER CONFIG ############
data "template_file" "container" {
  count = "${length(var.clusters)}"
  template = "${file("container.tpl")}"
  vars {
    role = "${element(var.clusters, count.index)}"
    port = "${lookup(var.ports, element(var.clusters, count.index))}"
    env = "${var.environment}"
    docker_repo = "${var.docker_repo}"
    version = "${var.arango_ver}",
    zone = "${var.az}",
    consul = "${lookup(var.consul, var.environment)}",
    graphite = "${lookup(var.graphite, var.environment)}"
  }
}

resource "aws_ecs_cluster" "arango" {
  count = "${length(var.clusters)}"
  name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
}

resource "aws_ecs_task_definition" "arango" {
  count = "${length(var.clusters)}"
  family = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
  container_definitions = "${element(data.template_file.container.*.rendered, count.index)}"
  volume {
    name = "data"
    host_path = "/data"
  }
}

resource "aws_ecs_service" "arango" {
  count = "${length(var.clusters)}"
  name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
  cluster = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
  task_definition = "${element(aws_ecs_task_definition.arango.*.arn, count.index)}"
  desired_count = "${lookup(var.num_instances, element(var.clusters, count.index))}"
  iam_role = "${format("arn:aws:iam::969968648862:role/%s", var.iam_role_name)}"
  load_balancer {
    elb_name = "${element(aws_elb.arango.*.name, count.index)}"
    container_name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
    container_port = "${lookup(var.ports, element(var.clusters, count.index))}"
  }
  depends_on = ["aws_iam_policy_attachment.arango_ecs_elb"]
}
############ ECS CLUSTER CONFIG END ############


############ CLOUD_INIT CONFIG ############
data "template_file" "init" {
  count = "${length(var.clusters)}"
  template = "${file("init.tpl")}"
  vars {
    cluster_name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
    region       = "${var.region}"
    consul = "${lookup(var.consul, var.environment)}"
    registrator_image = "${var.registrator_image}"
    zone = "${var.az}"
    env = "${var.environment}"
  }
}

data "template_cloudinit_config" "arango" {
  count = "${length(var.clusters)}"
  gzip = false
  base64_encode = false

  part {
    content_type = "text/cloud-boothook"
    content = "${file("mount_ebs.sh")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${element(data.template_file.init.*.rendered, count.index)}"
  }
}
############ CLOUD_INIT CONFIG END ############


############ EC2 AUTO_SCALING GROUP CONFIG ############
resource "aws_launch_configuration" "arango" {
  count = "${length(var.clusters)}"
  name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
  instance_type = "${lookup(var.sizes, element(var.clusters, count.index))}"
  image_id = "${var.ami}"
  iam_instance_profile = "arn:aws:iam::969968648862:instance-profile/ecsInstanceRole"
  security_groups = ["${var.security_group}"]
  user_data = "${element(data.template_cloudinit_config.arango.*.rendered, count.index)}"
  key_name = "${lookup(var.keypair, var.environment)}"
  ebs_block_device = {
    device_name = "/dev/sdg"
    volume_size = "${lookup(var.volume_size, element(var.clusters, count.index))}"
    volume_type = "gp2"
    delete_on_termination = true
    encrypted = true
  }
}

resource "aws_autoscaling_group" "ecs_cluster" {
  count = "${length(var.clusters)}"
  name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
  vpc_zone_identifier = ["${lookup(var.subnet, var.az)}"]
  min_size = "${lookup(var.num_instances, element(var.clusters, count.index))}"
  max_size = "${lookup(var.num_instances, element(var.clusters, count.index))}"
  desired_capacity = "${lookup(var.num_instances, element(var.clusters, count.index))}"
  launch_configuration = "${element(aws_launch_configuration.arango.*.name, count.index)}"
  health_check_type = "EC2"
  tag {
    key = "Name"
    value = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
    propagate_at_launch = "true"
  }
}
############ EC2 AUTO_SCALING GROUP CONFIG END ############


############ EC2 ELB CONFIG ############
resource "aws_elb" "arango" {
  count = "${length(var.clusters)}"
  name = "${format("%s-%s", element(var.clusters, count.index), var.az)}"
  subnets = ["${lookup(var.subnet, var.az)}"]
  security_groups = ["${var.security_group}"]
  internal = true
  listener {
    instance_port = "${lookup(var.ports, element(var.clusters, count.index))}"
    instance_protocol = "http"
    lb_port = "${lookup(var.ports, element(var.clusters, count.index))}"
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 10
    target = "${format("HTTP:%s/_admin/server/role", lookup(var.ports, element(var.clusters, count.index)))}"
    interval = 5
    timeout = 4
  }
}
############ EC2 ELB CONFIG END ############

