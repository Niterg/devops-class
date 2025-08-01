variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "zone" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "mero_public_subnet" {
  type    = list(string)
  default = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
}

variable "mero_private_subnet" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.32.0/19", "10.0.64.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "merokey"
}

variable "ubuntu_ami_owner" {
  description = "Canonical's AWS account ID for Ubuntu AMIs"
  type        = string
  default     = "099720109477"
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}