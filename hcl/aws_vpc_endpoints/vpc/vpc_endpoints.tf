################################################################################
# VPC Endpoints
################################################################################


module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.1"

  vpc_id = data.aws_vpc.get_vpc.id

  create_security_group      = true
  security_group_name_prefix = "${local.vpc_name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [data.aws_vpc.get_vpc.cidr_block]
    }
  }

  endpoints = merge({
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = [data.aws_route_table.selected.id]
      tags = {
        Name         = "${local.vpc_name}-s3"
      }
    }
    },
    { for service in toset(["autoscaling", "ecr.api", "ecr.dkr", "ec2", "ec2messages", "elasticloadbalancing", "sts", "kms", "logs", "ssm", "ssmmessages"]) :
      replace(service, ".", "_") =>
      {
        service             = service
        subnet_ids          = data.aws_subnets.get_subnets.ids
        private_dns_enabled = true
        tags = {
          Name         = "${local.vpc_name}-${service}"
        }
      }
    }
  )
}
