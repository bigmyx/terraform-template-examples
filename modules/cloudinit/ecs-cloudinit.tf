variable "cluster_name" {}

data "template_file" "init" {
  template = "${file("${path.module}/cloud-init.tpl")}"
  vars {
    cluster = "${var.cluster_name}"
  }
}

data "template_cloudinit_config" "app-cluster" {
  gzip = false
  base64_encode = false
  part {
    content_type = "text/cloud-boothook"
    content = "${file("${path.module}/mount_ebs.sh")}"
  }
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.init.rendered}"
  }
}

output "data" {
  value = "${data.template_cloudinit_config.app-cluster.rendered}"
}
