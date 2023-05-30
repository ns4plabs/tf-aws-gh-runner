# Cost considerations
# 1. NATGateway-Bytes - caused by traffic from private subnets to outside world
# https://github.com/philips-labs/terraform-aws-github-runner/issues/3163
# 2. DataTransfer-Regional-Bytes - caused by traffic between AZs in the same region
# Consider switching to single AZ i.e. use only one subnet or create a new VPC with only one AZ

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.2"

  name = "vpc-tf-aws-gh-runner"
  cidr = "10.0.0.0/16"

  # NOTE: modifying azs will force a replacement of quite a few resources
  # Make sure to allocate enough time and pick a time slot when no one is using the runners
  azs             = ["${data.aws_region.default.name}a", "${data.aws_region.default.name}b", "${data.aws_region.default.name}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames    = true
  enable_nat_gateway      = true
  map_public_ip_on_launch = true
  single_nat_gateway      = true

  enable_ipv6                     = true
  assign_ipv6_address_on_creation = true

  public_subnet_ipv6_prefixes   = [0, 1, 2]
  private_subnet_ipv6_prefixes  = [3, 4, 5]
  database_subnet_ipv6_prefixes = [6, 7, 8]

  tags = local.tags
}
