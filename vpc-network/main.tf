provider "aws" {
  region = "${var.region}"
}

###### Create Sec. Group for Instances #####
resource "aws_security_group" "staging_group" {
  name        = "staging-group-tf"
  description = "staging-group-tf"
  vpc_id      = "${var.existing_vpc_id}"

  # SSH access from Jump Host
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.jumphost_ip}"]
  }

  # Allow all traffic inside SG
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.20.5.0/24"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

