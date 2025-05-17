# modules/network_with_gateway/main.tf
resource "random_id" "suffix" {
  byte_length = 4
}


resource "scaleway_vpc" "this" {
  name = format("%s-vpc-%s-%s", var.project_name, var.region, random_id.suffix.hex)
  project_id     = var.project_id
  region         = var.region
  tags           = concat(["terraform", var.project_name, var.region], var.tags)
}

resource "scaleway_vpc_private_network" "this" {
  name       = format("%s-network-%s-%s", var.project_name, var.region, random_id.suffix.hex)
  project_id = var.project_id
  region     = var.region
  vpc_id     = scaleway_vpc.this.id
  tags       = concat(["terraform", var.project_name, var.region], var.tags)

  dynamic "ipv4_subnet" {
    for_each = var.ipv4_subnet != null ? [1] : []
    content {
      subnet = var.ipv4_subnet
    }
  }
}

resource "scaleway_vpc_public_gateway_ip" "this" {
  count = var.gw_enabled && var.gw_reserve_ip ? 1 : 0
  project_id = var.project_id
  tags       = concat(["terraform", var.project_name, var.region, random_id.suffix.hex], var.tags)
  zone       = var.zone
}



resource "scaleway_vpc_public_gateway" "this" {
  count = var.gw_enabled ? 1 : 0
  bastion_enabled = var.bastion_enabled
  bastion_port    = var.bastion_port
  enable_smtp     = var.smtp_enabled
  ip_id           = var.gw_reserve_ip ? scaleway_vpc_public_gateway_ip.this[count.index].id : null
  name            = format("%s-gateway-%s", var.project_name, var.region)
  project_id      = var.project_id
  tags            = concat(["terraform", var.project_name, var.region], var.tags)
  type            = var.gw_type
  zone            = var.zone
}

resource "scaleway_vpc_gateway_network" "this" {
  count = var.gw_enabled ? 1 : 0
  enable_masquerade  = var.masquerade_enabled
  gateway_id         = scaleway_vpc_public_gateway.this[count.index].id
  private_network_id = scaleway_vpc_private_network.this.id
  zone               = var.zone
  static_address     = var.ipv4_subnet
}