output "subnet_ids" {
  description = "List of private subnet IDs"
  value       = data.aws_subnets.get_subnets.ids
}

output "vpc_id" {
  description = "VPC ID being used"
  value       = data.aws_vpc.get_vpc.id
}
