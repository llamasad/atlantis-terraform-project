terraform {
  cloud {
    organization = "organization-aws-1"
    workspaces {
      name = "production-workspace"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_vpc" "production_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "production"
  }
}

resource "aws_internet_gateway" "production_igw" {
  vpc_id = aws_vpc.production_vpc.id
  tags = {
    name = "production"
  }
}

resource "aws_egress_only_internet_gateway" "production_igw-egress-gw" {
  vpc_id = aws_vpc.production_vpc.id
}

resource "aws_route_table" "production_route_table" {
  vpc_id = aws_vpc.production_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.production_igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.production_igw-egress-gw.id
  }

  tags = {
    name = "production"
  }
}

resource "aws_subnet" "production_public-subnet" {
  vpc_id            = aws_vpc.production_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    name = "production-public"
  }
}

resource "aws_route_table_association" "production_public-subnet_association" {
  subnet_id      = aws_subnet.production_public-subnet.id
  route_table_id = aws_route_table.production_route_table.id
}

resource "aws_security_group" "production_public-sg" {
  vpc_id = aws_vpc.production_vpc.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_network_interface" "production_web-server-nic" {
  subnet_id       = aws_subnet.production_public-subnet.id
  security_groups = [aws_security_group.production_public-sg.id]
  private_ips     = ["10.0.1.50"]
  tags = {
    name = "production_web-server-nic"
  }
}

resource "aws_instance" "production_web-server" {
  ami               = "ami-0497a974f8d5dcef8"
  instance_type     = "t2.micro"
  key_name          = "main-key"
  availability_zone = "ap-southeast-1a"

  network_interface {
    network_interface_id = aws_network_interface.production_web-server-nic.id
    device_index         = 0
  }
  tags = {
    name = "production_web-server"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>production instance deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
              EOF
}

resource "aws_eip" "production_web-server-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.production_web-server-nic.id
  associate_with_private_ip = "10.0.1.50"

  tags = {
    name = "production_web-server-eip"
  }
  depends_on = [aws_instance.production_web-server]
}
