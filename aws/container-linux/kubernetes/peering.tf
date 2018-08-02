variable "management_vpc_id" {}

variable "management_sg" {}

data "aws_vpc" "management" {
  id = "${var.management_vpc_id}"
}

# TODO: Do we need to add to all route tables in management?
data "aws_route_tables" "management" {
  vpc_id = "${var.management_vpc_id}"
}

output "vpc_peer" {
  value = "${aws_vpc_peering_connection.management.id}"
}

########## VPC Peering ##########

resource "aws_vpc_peering_connection" "management" {
  vpc_id      = "${aws_vpc.network.id}"
  peer_vpc_id = "${var.management_vpc_id}"

  auto_accept = true

  tags {
    Name = "${var.cluster_name}"
  }
}

# kubernetes --> management
# TODO: create additional route tables for cluster
resource "aws_route" "to_management" {
  count                     = "${length(data.aws_route_tables.management.ids)}"
  route_table_id            = "${element(aws_route_table.private.*.id, count.index)}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.management.id}"
  destination_cidr_block    = "${data.aws_vpc.management.cidr_block}"

  # destination_ipv6_cidr_block = "${data.aws_vpc.management.ipv6_cidr_block}"
}

# kubernetes <-- management
resource "aws_route" "to_cluster" {
  count                     = "${length(data.aws_route_tables.management.ids)}"
  route_table_id            = "${element(data.aws_route_tables.management.ids, count.index)}"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.management.id}"
  destination_cidr_block    = "${aws_vpc.network.cidr_block}"

  # destination_ipv6_cidr_block = "${data.aws_vpc.management.ipv6_cidr_block}"
}

########## Security Group Rules ##########

resource "aws_security_group_rule" "api" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  security_group_id        = "${aws_security_group.controller.id}"
  source_security_group_id = "${var.management_sg}"

  depends_on = ["aws_vpc_peering_connection.management"]
}

# k8s app-templates exposed with service_type: nodePort will be accessed though any node IP
resource "aws_security_group_rule" "allow_all" {
  count     = 2
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  security_group_id        = "${element(list(aws_security_group.controller.id, aws_security_group.worker.id), count.index)}"
  source_security_group_id = "${var.management_sg}"

  depends_on = ["aws_vpc_peering_connection.management"]
}
