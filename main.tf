provider "aws" {
  region = "eu-west-2"
}

resource "tls_private_key" "gen_ssh_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "aws_ptfe_sandbox_keypair" {
  key_name   = "aws-ptfe-sandbox-psouter"
  public_key = "${tls_private_key.gen_ssh_key.public_key_openssh}"
}

resource "local_file" "aws_ssh_key_pem" {
  depends_on = ["tls_private_key.gen_ssh_key"]
  content    = "${tls_private_key.gen_ssh_key.private_key_pem}"
  filename   = "./keys/aws-ptfe-sandbox-keypair.pem"
}


data "aws_ami" "xenial_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
}

resource "aws_security_group" "allow_ptfe_access" {
  name = "allow-ptfe-access-sandbox"

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }

  ingress {
    from_port = "22"
    to_port   = "22"
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8800
    to_port     = 8800
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "replicated_settings" {
  template = "${file("${path.module}/config/replicated-settings.tpl.json")}"
}

data "template_file" "replicated_conf" {
  template = "${file("${path.module}/config/replicated.tpl.conf")}"
}


resource "aws_instance" "ptfe_instance" {
  ami                    = "${data.aws_ami.xenial_ami.image_id}"
  instance_type          = "m5.xlarge"
  vpc_security_group_ids = [
    "${aws_security_group.allow_ptfe_access.id}",
  ]

  associate_public_ip_address = true

  key_name = "${aws_key_pair.aws_ptfe_sandbox_keypair.key_name}"

  root_block_device {
    volume_size = 100
    volume_type = "gp2"
  }

  ebs_block_device {
    volume_size = 88
    volume_type = "gp2"
    device_name = "/dev/xvdb" # This is ignored by the instance, which mounts it as /dev/nvme1n1
  }

  tags {
    Name = "ptfe_instance"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs -t ext4 /dev/nvme1n1",
      "sudo mkdir /data",
      "sudo mount /dev/nvme1n1 /data",
      "sudo mkdir -p /var/ptfe-installer/",
      "sudo chown ubuntu /var/ptfe-installer/",
      "sudo hostnamectl set-hostname ${aws_instance.ptfe_instance.public_dns}",
    ]

    connection {
      user        = "ubuntu"
      private_key = "${tls_private_key.gen_ssh_key.private_key_pem}"
    }
  }

  provisioner "file" {
    source      = "${path.module}/config/license.rli"
    destination = "/var/ptfe-installer/license.rli"

    connection {
      user        = "ubuntu"
      private_key = "${tls_private_key.gen_ssh_key.private_key_pem}"
    }
  }

  provisioner "file" {
    content     = "${data.template_file.replicated_conf.rendered}"
    destination = "/var/ptfe-installer/replicated.conf"

    connection {
      user        = "ubuntu"
      private_key = "${tls_private_key.gen_ssh_key.private_key_pem}"
    }
  }

  provisioner "file" {
    content     = "${data.template_file.replicated_settings.rendered}"
    destination = "/var/ptfe-installer/settings.json"

    connection {
      user        = "ubuntu"
      private_key = "${tls_private_key.gen_ssh_key.private_key_pem}"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /var/ptfe-installer/replicated.conf /etc/replicated.conf",
      "sudo sed -i 's/CHANGEME/${aws_instance.ptfe_instance.public_dns}/' /etc/replicated.conf",
      "sudo sed -i 's/CHANGEME/${aws_instance.ptfe_instance.public_dns}/' /var/ptfe-installer/settings.json",
      "sudo chmod 0644 /etc/replicated.conf /var/ptfe-installer/settings.json /var/ptfe-installer/license.rli",
      "curl -sSL -o install.sh https://get.replicated.com/docker/terraformenterprise/stable",
      "sudo bash install.sh no-proxy"
    ]

    connection {
      user        = "ubuntu"
      private_key = "${tls_private_key.gen_ssh_key.private_key_pem}"
    }
  }

}

output "ptfe_instance_ip" {
  value = "${aws_instance.ptfe_instance.public_ip}"
}

output "ptfe_replicated_ip" {
  value = "https://${aws_instance.ptfe_instance.public_ip}:8800"
}
