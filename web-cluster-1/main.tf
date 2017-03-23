provider "aws" {
  region = "${var.region}"
}

module "iam" {
  source = "../modules/iam"
  cluster_name = "${var.cluster_name}-${terraform.env}"
  cert_bucket = "${var.cert_bucket}"
}

############ ECS CLUSTER CONFIG ############
resource "aws_ecs_cluster" "app-cluster" {
  name = "${var.cluster_name}-${terraform.env}"
}

data "template_file" "container" {
  count = "${length(var.services)}"
  template = "${file("container.tpl")}"
  vars {
    service = "${element(var.services, count.index)}"
    container_port = "${var.container_ports[element(var.services, count.index)]}"
    env = "${terraform.env}"
    docker_image = "${var.images[element(var.services, count.index)]}"
    version = "${var.versions[element(var.services, count.index)]}"
    config_db_name = "${var.env_vars["config_db_name"]}"
  }
}

resource "aws_ecs_task_definition" "app-task" {
  count = "${length(var.services)}"
  family = "${element(var.services, count.index)}-${var.versions[element(var.services, count.index)]}"
  container_definitions = "${element(data.template_file.container.*.rendered, count.index)}"
  volume {
    name = "logs"
    host_path = "/var/log/obs"
  }
  volume {
    name = "logdata"
    host_path = "/cdlogdata"
  }
}

resource "aws_ecs_service" "app-service" {
  count = "${length(var.services)}"
  name = "${element(var.services, count.index)}-${var.versions[element(var.services, count.index)]}"
  cluster = "${var.cluster_name}-${terraform.env}"
  task_definition = "${element(aws_ecs_task_definition.app-task.*.arn, count.index)}"
  desired_count = 1
  iam_role = "${module.iam.ecs_service_role_name}"
  load_balancer {
    target_group_arn = "${element(aws_alb_target_group.app-service.*.id, count.index)}"
    container_name = "${element(var.services, count.index)}-${var.versions[element(var.services, count.index)]}"
    container_port = "${var.container_ports[element(var.services, count.index)]}"
  }
  depends_on = ["module.iam", "aws_alb_listener.app-service"]
  lifecycle {
    create_before_destroy = true
    ignore_changes = ["desired_count"]
  }
}
############ ECS CLUSTER CONFIG END ############

resource "null_resource" "health_check" {
  count = "${length(var.services)}"
  triggers {
    cluster_task_ids = "${join(",", aws_ecs_task_definition.app-task.*.id)}"
  }
  provisioner "local-exec" {
    command = <<EOL
      python \
      health_check.py \
      ${var.cluster_name}-${terraform.env} \
      ${element(var.services, count.index)}-${var.versions[element(var.services, count.index)]} \
      ${element(aws_alb_target_group.app-service.*.arn, count.index)}
    EOL
  }
}

module "ecs-cloudinit" {
  source = "../modules/cloudinit"
  cluster_name = "${var.cluster_name}-${terraform.env}"
}

module "asg" {
  source = "../modules/asg"
  name = "${var.cluster_name}-${terraform.env}"
  instance_type = "${var.instance_size}"
  image_id = "${var.ami}"
  iam_instance_profile = "${module.iam.aws_instance_profile_name}"
  security_groups = "${split(",", terraform.env == "staging" ? var.ec2_security_groups_stg : var.ec2_security_groups_prod)}"
  user_data = "${module.ecs-cloudinit.data}"
  key_name = "${var.keypair[terraform.env]}"
  volume_size = "${var.volume_size}"
  subnets = "${var.subnets}"
  min_size = "${length(var.services)}"
  max_size = "${length(var.services)}"
}


############ EC2 ALB CONFIG ############
resource "aws_alb_target_group" "app-service" {
  count = "${length(var.services)}"
  name = "${element(var.services, count.index)}-${terraform.env}"
  port = "${var.elb_ports[element(var.services, count.index)]}"
  protocol = "${var.schemes[element(var.services, count.index)]}"
  vpc_id = "${var.vpc}"
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 10
    path = "${format("/%s/healthCheck", element(var.services, count.index))}"
    protocol = "${var.schemes[element(var.services, count.index)]}"
    interval = 5
    timeout = 4
    matcher = "200
  }
}

resource "aws_alb" "main" {
  internal = true
  name = "${element(var.services, count.index)}-${terraform.env}"
  subnets = "${var.subnets}"
  security_groups = "${split(",", terraform.env == "staging" ? var.elb_security_groups_stg : var.elb_security_groups_prod)}"

}

resource "aws_alb_listener" "app-service" {
  count = "${length(var.services)}"
  load_balancer_arn = "${aws_alb.main.id}"
  port = "${var.elb_ports[element(var.services, count.index)]}"
  protocol = "${var.schemes[element(var.services, count.index)]}"
  certificate_arn = "${element(var.services, count.index) == "kms" ? "" : var.certificates[terraform.env]}" #KMS Does not need a cert
  default_action {
    target_group_arn = "${element(aws_alb_target_group.app-service.*.id, count.index)}"
    type = "forward"
  }
}
############ EC2 ALB CONFIG END ############
