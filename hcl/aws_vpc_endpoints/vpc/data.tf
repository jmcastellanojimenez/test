################################################################################
# Supporting Resources
################################################################################

data "aws_vpc" "get_vpc" {
  id = var.vpc_id
}

data "aws_subnets" "get_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.get_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*priv*"]
  }
}

data "aws_route_table" "selected" {
  subnet_id = tolist(data.aws_subnets.get_subnets.ids)[0]
}

locals {
  vpc_name = lookup(data.aws_vpc.get_vpc.tags, "Name", "vpc-unnamed")
}