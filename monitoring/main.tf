provider "aws" {
  region = "${var.region}"
}

data "template_file" "container" {
  template = "${file("container.tpl")}"
  vars {
    env = "${var.env}"
    config_db_name = "${var.db_name}"
  }
}

resource "aws_ecs_task_definition" "task" {
  family = "${var.service}"
  container_definitions = "${data.template_file.container.rendered}"
}

resource "aws_ecs_service" "service" {
  name = "${var.service}"
  cluster = "${var.cluster}"
  task_definition = "${aws_ecs_task_definition.task.arn}"
  desired_count = "${var.num_tasks}"
}

