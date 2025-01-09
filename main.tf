
# vpn client admin guide https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/what-is.html

# create self signed certs for authentication https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/authentication-authrization.html

resource "aws_cloudwatch_log_group" "client_vpn_log_group" {
  name = "/aws/vpn/${var.stage}-${var.auth_type}"
}

resource "aws_cloudwatch_log_stream" "client_vpn_log_stream" {
  name           = "${var.stage}-vpn-msad"
  log_group_name = aws_cloudwatch_log_group.client_vpn_log_group.name
}

#
# client vpn for certificate authentication
#
resource "aws_ec2_client_vpn_endpoint" "client_vpn" {
  count       = (var.auth_type == "certificate") ? 1 : 0
  description = "client vpn for ${var.stage} certificte"

  server_certificate_arn = var.vpn_server_arn
  client_cidr_block      = var.client_cidr_block
  dns_servers            = ["${var.vpn_dns}"]

  authentication_options {
    type                       = "certificate-authentication" # certificate auth
    root_certificate_chain_arn = var.vpn_client_arn           # client certificate arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn_log_group.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn_log_stream.name
  }

  tags = {
    Name    = "${var.stage} client vpn certificate auth"
    Managed = "managed by terraform"
  }
  security_group_ids = var.security_group_ids
}


#
# client vpn for MS AD authentication
#
resource "aws_ec2_client_vpn_endpoint" "client_vpn_msad" {
  count       = (var.auth_type == "certificate") ? 0 : 1
  description = "client vpn for ${var.stage} msad"

  server_certificate_arn = var.vpn_server_arn
  client_cidr_block      = var.client_cidr_block
  dns_servers            = ["${var.vpn_dns}"]

  authentication_options {
    type                = "directory-service-authentication" # active directory
    active_directory_id = var.active_directory_id            # ms ad connector in aws that connects to remote AD server
    #active_directory_id = "d-92670a3d47" # ms ad connector from aws
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn_log_group.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn_log_stream.name
  }

  tags = {
    Name    = "${var.stage} client vpn MS AD auth"
    Managed = "managed by terraform"
  }
}


# set up association
resource "aws_ec2_client_vpn_network_association" "client_vpn_connection" {
  client_vpn_endpoint_id = coalesce(flatten([aws_ec2_client_vpn_endpoint.client_vpn.*.id, aws_ec2_client_vpn_endpoint.client_vpn_msad.*.id])...)
  subnet_id              = var.subnet_id
}

# set up a route to the internet
resource "aws_ec2_client_vpn_route" "vpn_route_internet" {
  client_vpn_endpoint_id = coalesce(flatten([aws_ec2_client_vpn_endpoint.client_vpn.*.id, aws_ec2_client_vpn_endpoint.client_vpn_msad.*.id])...)
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.client_vpn_connection.subnet_id
}

# # original
# # authorize ingress from the vpc
# resource "aws_ec2_client_vpn_authorization_rule" "authorize_vpc" {
#   client_vpn_endpoint_id = coalesce(flatten([aws_ec2_client_vpn_endpoint.client_vpn.*.id, aws_ec2_client_vpn_endpoint.client_vpn_msad.*.id])...)
#   target_network_cidr    = var.vpc_cidr
#   authorize_all_groups   = true
# }

# # authorize ingress from internet if enabled
# resource "aws_ec2_client_vpn_authorization_rule" "authorize_internet" {
#   count                  = var.authorize_internet == true ? 1 : 0
#   client_vpn_endpoint_id = coalesce(flatten([aws_ec2_client_vpn_endpoint.client_vpn.*.id, aws_ec2_client_vpn_endpoint.client_vpn_msad.*.id])...)
#   target_network_cidr    = "0.0.0.0/0"
#   authorize_all_groups   = true
# }

# locals {
#   use_auth_routes = auth_routes == "default" 

#   {
#     "0.0.0.0/0"       = "true"
#     "${var.vpc_cidr}" = "true"
#   }
# }

resource "aws_ec2_client_vpn_authorization_rule" "certificate_authorize_rule" {
  count                  = (var.auth_type == "certificate") ? length(var.auth_routes) : 0
  client_vpn_endpoint_id = coalesce(flatten([aws_ec2_client_vpn_endpoint.client_vpn.*.id, aws_ec2_client_vpn_endpoint.client_vpn_msad.*.id])...)
  target_network_cidr    = element(keys(var.auth_routes), count.index) == "vpc_cidr" ? var.vpc_cidr : element(keys(var.auth_routes), count.index)
  authorize_all_groups   = true
  depends_on             = [aws_ec2_client_vpn_endpoint.client_vpn]
}

resource "aws_ec2_client_vpn_authorization_rule" "msad_authorize_rule" {
  count                  = (var.auth_type == "certificate") ? 0 : length(var.auth_routes)
  client_vpn_endpoint_id = coalesce(flatten([aws_ec2_client_vpn_endpoint.client_vpn.*.id, aws_ec2_client_vpn_endpoint.client_vpn_msad.*.id])...)
  target_network_cidr    = element(keys(var.auth_routes), count.index) == "vpc_cidr" ? var.vpc_cidr : element(keys(var.auth_routes), count.index)
  #authorize_all_groups   = true
  access_group_id        = element(values(var.auth_routes), count.index)
  depends_on             = [aws_ec2_client_vpn_endpoint.client_vpn_msad]
}
