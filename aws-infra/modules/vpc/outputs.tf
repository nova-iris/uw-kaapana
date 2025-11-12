output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = module.vpc.igw_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways"
  value       = module.vpc.natgw_ids
}

output "nat_gateway_id" {
  description = "ID of the first NAT gateway (for backward compatibility)"
  value       = module.vpc.natgw_ids[0]
}

output "nat_gateway_eip" {
  description = "Elastic IP of the first NAT gateway (for backward compatibility)"
  value       = module.vpc.natgw_ids[0] != null ? module.vpc.natgw_ids[0] : null
}