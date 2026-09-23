data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  # Carve the VPC into equal blocks, public first then private, so that adding an
  # AZ appends subnets instead of renumbering the existing ones.
  newbits = ceil(log(var.availability_zone_count * 2, 2))

  public_subnets  = { for idx, az in local.azs : az => cidrsubnet(var.cidr_block, local.newbits, idx) }
  private_subnets = { for idx, az in local.azs : az => cidrsubnet(var.cidr_block, local.newbits, idx + var.availability_zone_count) }

  nat_gateway_azs = {
    single = slice(local.azs, 0, 1)
    per_az = local.azs
    none   = []
  }[var.nat_gateway_strategy]

  cluster_tags = var.cluster_name == "" ? {} : {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(var.tags, local.cluster_tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
    # Read by the AWS Load Balancer Controller when placing internet-facing ALBs.
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, local.cluster_tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
    # Read by the AWS Load Balancer Controller when placing internal load balancers.
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_azs)

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# One table per AZ regardless of NAT strategy: association logic stays uniform and
# the strategy can change without recreating subnets.
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route" "private_nat" {
  for_each = var.nat_gateway_strategy == "none" ? {} : local.private_subnets

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.nat_gateway_strategy == "single" ? local.nat_gateway_azs[0] : each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ECR layers are served from S3. A gateway endpoint keeps image pulls off the NAT
# gateways at no additional cost.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], [for rt in aws_route_table.private : rt.id])

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}
