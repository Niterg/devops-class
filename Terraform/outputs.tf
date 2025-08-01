output "instance_public_ips" {
  description = "Public IP addresses of the instances in public subnets"
  value = {
    for i, instance in aws_instance.mero_instances :
    instance.tags.Name => instance.public_ip if i < 2
  }
}

output "instance_private_ips" {
  description = "Private IP addresses of all instances"
  value = {
    for instance in aws_instance.mero_instances :
    instance.tags.Name => instance.private_ip
  }
}

output "vpc_id" {
  description = "ID of the Mero VPC"
  value       = aws_vpc.mero_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.mero_public_subnet[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.mero_private_subnet[*].id
}