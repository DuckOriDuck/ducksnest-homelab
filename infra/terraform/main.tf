# Ubuntu 24.04 LTS based EC2 instances
terraform {
  required_version = ">= 1.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "ducksnest-terraform-state"
    key            = "homelab/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    kms_key_id     = "alias/ducksnest-terraform-state-key"
    dynamodb_table = "ducksnest-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}


# Custom baked AMI
data "aws_ami" "nixos_custom" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["NixOS-25.05-tailscaled-ver2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Needed Roles for CP
data "aws_iam_instance_profile" "k8s_cp_profile" {
  name = "homelab-cp-role"
}

# EC2 Instances
resource "aws_instance" "k8s_control_plane" {
  ami                    = data.aws_ami.nixos_custom.id
  instance_type          = "t3.medium"
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_c.id
  vpc_security_group_ids = [aws_security_group.strict_egress.id]
  iam_instance_profile   = data.aws_iam_instance_profile.k8s_cp_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  user_data = templatefile("./user-data/k8s-cp-tailscale.sh", {
    hostname   = "ducksnest-cp",
    aws_region = var.aws_region
  })

  tags = {
    Name          = "ducksnest-k8s-control-plane"
    Environment   = "homelab"
    Role          = "k8s-control-plane"
    Ansible_Group = "k8s_control_plane"
  }
}

# Outputs
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

