terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "my-key-pair"
}

# SSH Key Pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "devops-stack-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devops-stack-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "devops-stack-public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "devops-stack-private-subnet-${count.index + 1}"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "devops-stack-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "web" {
  name_prefix = "devops-stack-web-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Internal communication between services
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Allow from VPC
    description = "Vault API access"
  }

  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "OPA API access"
  }

  # Allow all internal traffic between instances
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Internal communication"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# AMI for Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# GitLab EC2 Instance
resource "aws_instance" "gitlab" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io curl jq
              systemctl start docker
              systemctl enable docker

              # Note: Integration with Vault and OPA requires manual configuration
              # after deployment using the private IPs from Terraform outputs

              docker run -d --name gitlab -p 80:80 -p 443:443 -p 22:22 \
                --env GITLAB_OMNIBUS_CONFIG="external_url 'http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)'; gitlab_rails['initial_root_password'] = 'password123';" \
                gitlab/gitlab-ce:latest
              EOF

  tags = {
    Name = "GitLab-Instance"
  }
}

# Vault EC2 Instance
resource "aws_instance" "vault" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public[1].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y unzip
              wget https://releases.hashicorp.com/vault/1.13.0/vault_1.13.0_linux_amd64.zip
              unzip vault_1.13.0_linux_amd64.zip
              mv vault /usr/local/bin/
              useradd --system --home /etc/vault.d --shell /bin/false vault
              mkdir -p /etc/vault.d
              cat > /etc/vault.d/vault.hcl <<EOL
              storage "file" {
                path = "/opt/vault/data"
              }
              listener "tcp" {
                address = "0.0.0.0:8200"
                tls_disable = 1
              }
              ui = true
              EOL
              mkdir -p /opt/vault/data
              chown -R vault:vault /opt/vault /etc/vault.d
              cat > /etc/systemd/system/vault.service <<EOL
              [Unit]
              Description=Vault
              [Service]
              User=vault
              Group=vault
              ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
              [Install]
              WantedBy=multi-user.target
              EOL
              systemctl enable vault
              systemctl start vault
              EOF

  tags = {
    Name = "Vault-Instance"
  }
}

# OPA EC2 Instance
resource "aws_instance" "opa" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              wget https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64
              mv opa_linux_amd64 /usr/local/bin/opa
              chmod +x /usr/local/bin/opa
              cat > /etc/systemd/system/opa.service <<EOL
              [Unit]
              Description=Open Policy Agent
              [Service]
              ExecStart=/usr/local/bin/opa run --server --addr :8181
              [Install]
              WantedBy=multi-user.target
              EOL
              systemctl enable opa
              systemctl start opa
              EOF

  tags = {
    Name = "OPA-Instance"
  }
}

# Outputs
output "gitlab_public_ip" {
  description = "Public IP of GitLab instance"
  value       = aws_instance.gitlab.public_ip
}

output "vault_public_ip" {
  description = "Public IP of Vault instance"
  value       = aws_instance.vault.public_ip
}

output "opa_public_ip" {
  description = "Public IP of OPA instance"
  value       = aws_instance.opa.public_ip
}

output "gitlab_private_ip" {
  description = "Private IP of GitLab instance"
  value       = aws_instance.gitlab.private_ip
}

output "vault_private_ip" {
  description = "Private IP of Vault instance"
  value       = aws_instance.vault.private_ip
}

output "opa_private_ip" {
  description = "Private IP of OPA instance"
  value       = aws_instance.opa.private_ip
}

output "private_key" {
  description = "Private key for SSH access"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}