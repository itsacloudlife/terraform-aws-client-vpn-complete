# variables used

variable "stage" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vpn_dns" {
  type = string
}

variable "vpn_server_arn" {
  type = string
}

variable "vpn_client_arn" {
  type = string
  description = "client certificate for certificate auth.  can be blank if doing msad auth"
  default = ""
}

variable "client_cidr_block" {
  type = string
}

variable "vpc_cidr" {
  type        = string
  description = "the vpc_cidr block"
}

variable "authorize_internet" {
  type        = bool
  default     = true
  description = "whether or not to authorize access to the internet"
}

variable "auth_type" {
  type        = string
  description = "type of authentication for the VPN client; choices: certificate, msad"
  default     = "certificate"
}

variable "active_directory_id" {
  type        = string
  description = "if auth_type is msad (microsoft AD) then this specifies the ID of the active_directory"
  default     = ""
}


variable "auth_routes" {
  type = map
  default = {
    "0.0.0.0/0"     = "true"
    "10.111.0.0/16" = "true"
    "vpc_cidr"      = "true"
  }
}