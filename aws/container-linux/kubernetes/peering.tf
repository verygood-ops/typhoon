data "aws_vpc" "k8s" {
  id = "${data.terraform_remote_state.kops.vpc_id}"
}

data "aws_security_group" "k8s_api" {
  name = "api-elb.${data.terraform_remote_state.kops.cluster_name}"
}

data "aws_subnet_ids" "k8s_utility" {
  vpc_id = "${data.terraform_remote_state.kops.vpc_id}"

  tags {
    SubnetType = "Utility"
  }
}

data "aws_subnet_ids" "k8s_private" {
  vpc_id = "${data.terraform_remote_state.kops.vpc_id}"

  tags {
    SubnetType = "Private"
  }
}

data "aws_route_table" "k8s" {
  count     = "${length(data.aws_subnet_ids.k8s_private.ids) + 1}"
  subnet_id = "${element(concat(data.aws_subnet_ids.k8s_private.ids, list(data.aws_subnet_ids.k8s_utility.ids[0])), count.index)}"
}

#--------------------------------------------------------------
# Creates the resources k8s vpc resources necessary
# for VPC peering connection with genpop to work.
#--------------------------------------------------------------

variable "management_vpc_id" {
  default = ""
}

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
  route_table_id              = "${aws_route_table.default.id}"
  vpc_peering_connection_id   = "${aws_vpc_peering_connection.management.id}"
  destination_cidr_block      = "${data.aws_vpc.management.cidr_block}"
  destination_ipv6_cidr_block = "${data.aws_vpc.management.ipv6_cidr_block}"
}

# kubernetes <-- management
resource "aws_route" "to_cluster" {
  count                       = "${length(data.aws_route_tables.management.ids)}"
  vpc_peering_connection_id   = "${aws_vpc_peering_connection.management.id}"
  route_table_id              = "${element(data.aws_route_tables.management.ids, count.index)}"
  destination_cidr_block      = "${data.aws_vpc.management.cidr_block}"
  destination_ipv6_cidr_block = "${data.aws_vpc.management.ipv6_cidr_block}"
}

########## Security Group Rules ##########

resource "aws_security_group_rule" "api" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  security_group_id        = "${data.aws_security_group.k8s_api.id}"
  source_security_group_id = "${var.bastion_sg}"

  depends_on = ["aws_vpc_peering_connection.genpop-vpc-peer"]
}

# k8s app-templates exposed with service_type: nodePort will be accessed though any node IP
resource "aws_security_group_rule" "allow_all" {
  count     = "${length(concat(data.terraform_remote_state.kops.master_security_group_ids, data.terraform_remote_state.kops.node_security_group_ids))}"
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  security_group_id        = "${element(concat(data.terraform_remote_state.kops.master_security_group_ids, data.terraform_remote_state.kops.node_security_group_ids), count.index)}"
  source_security_group_id = "${var.bastion_sg}"

  depends_on = ["aws_vpc_peering_connection.genpop-vpc-peer"]
}
