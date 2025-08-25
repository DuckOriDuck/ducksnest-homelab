# Ubuntu 24.04 LTS based EC2 instances
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

                  
# AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSM setting
data "aws_iam_role" "existing_ssm_role" {
  name = "ec2-role-for-ssm"
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ducksnest-ec2-ssm-profile"
  role = data.aws_iam_role.existing_ssm_role.name
}

# EC2 Instances
resource "aws_instance" "jenkins_headscale" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t4g.small"
  key_name             = var.key_name
  subnet_id            = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.strict_egress.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("./user-data/jenkins-headscale.sh", {
    hostname = "ducksnest-jenkins"
  })

  tags = {
    Name = "ducksnest-jenkins-headscale"
    Environment = "homelab"
    Role = "jenkins-headscale"
    Ansible_Group = "jenkins_headscale"
  }
}

resource "aws_instance" "k8s_control_plane" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t4g.medium"
  key_name             = var.key_name
  subnet_id            = aws_subnet.public_c.id
  vpc_security_group_ids = [aws_security_group.strict_egress.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("./user-data/k8s-control-plane.sh", {
    hostname = "ducksnest-controlplane"
  })

  tags = {
    Name = "ducksnest-k8s-control-plane"
    Environment = "homelab"
    Role = "k8s-control-plane"
    Ansible_Group = "k8s_control_plane"
  }
}

# Outputs
output "jenkins_headscale_public_ip" {
  description = "Public IP of Jenkins/Headscale server"
  value       = aws_instance.jenkins_headscale.public_ip
}

output "jenkins_headscale_private_ip" {
  description = "Private IP of Jenkins/Headscale server"
  value       = aws_instance.jenkins_headscale.private_ip
}

output "k8s_control_plane_public_ip" {
  description = "Public IP of Kubernetes Control Plane"
  value       = aws_instance.k8s_control_plane.public_ip
}

output "k8s_control_plane_private_ip" {
  description = "Private IP of Kubernetes Control Plane"
  value       = aws_instance.k8s_control_plane.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_a_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public_a.id
}

output "subnet_c_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public_c.id
}

