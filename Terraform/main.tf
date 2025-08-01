terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.6.0"
    }
  }
  backend "s3" {
    bucket         = "mero-terraform-state"
    key            = "state"
    region         = "us-east-1"
    access_key     = ""
    secret_key     = ""
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ubuntu_ami_owner]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# VPC and Networking Resources
resource "aws_vpc" "mero_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "MeroVPC"
  }
}

resource "aws_subnet" "mero_public_subnet" {
  count                   = length(var.mero_public_subnet)
  vpc_id                  = aws_vpc.mero_vpc.id
  depends_on              = [aws_vpc.mero_vpc]
  availability_zone       = element(var.zone, count.index)
  cidr_block              = element(var.mero_public_subnet, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "MeroPublicSubnet-${count.index + 1}"
  }
}

resource "aws_subnet" "mero_private_subnet" {
  count                   = length(var.mero_private_subnet)
  vpc_id                  = aws_vpc.mero_vpc.id
  depends_on              = [aws_vpc.mero_vpc]
  availability_zone       = element(var.zone, count.index)
  cidr_block              = element(var.mero_private_subnet, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "MeroPrivateSubnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "mero_igw" {
  vpc_id     = aws_vpc.mero_vpc.id
  depends_on = [aws_vpc.mero_vpc]
  tags = {
    Name = "MeroInternetGateway"
  }
}

resource "aws_eip" "mero_eip" {
  depends_on = [aws_internet_gateway.mero_igw]
  tags = {
    Name = "MeroEIP"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  depends_on    = [aws_internet_gateway.mero_igw]
  allocation_id = aws_eip.mero_eip.id
  subnet_id     = aws_subnet.mero_public_subnet[0].id
  tags = {
    Name = "MeroNATGateway"
  }
}

resource "aws_route_table" "mero_public_route_table" {
  vpc_id = aws_vpc.mero_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mero_igw.id
  }
  tags = {
    Name = "MeroPublicRouteTable"
  }
}

resource "aws_route_table" "mero_private_route_table" {
  vpc_id = aws_vpc.mero_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "MeroPrivateRouteTable"
  }
}

resource "aws_route_table_association" "mero_public_subnet_association" {
  count          = length(aws_subnet.mero_public_subnet)
  subnet_id      = aws_subnet.mero_public_subnet[count.index].id
  route_table_id = aws_route_table.mero_public_route_table.id
}

resource "aws_route_table_association" "mero_private_subnet_association" {
  count          = length(aws_subnet.mero_private_subnet)
  subnet_id      = aws_subnet.mero_private_subnet[count.index].id
  route_table_id = aws_route_table.mero_private_route_table.id
}

# Security Group
resource "aws_security_group" "mero_instance_sg" {
  name        = "mero-instance-sg"
  description = "Security group for Mero instances"
  vpc_id      = aws_vpc.mero_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MeroInstanceSG"
  }
}

# EC2 Instances
resource "aws_instance" "mero_instances" {
  count         = 3
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.mero_instance_sg.id]

  subnet_id = count.index < 2 ? aws_subnet.mero_public_subnet[count.index].id : aws_subnet.mero_private_subnet[0].id

  tags = {
    Name = "MeroInstance-${count.index + 1}"
  }
}