resource "aws_subnet" "public" {
  count      = 0
  vpc_id     = ""
  cidr_block = ""
}

resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.all.names)}"

  vpc_id            = "${aws_vpc.network.id}"
  availability_zone = "${data.aws_availability_zones.all.names[count.index]}"

  cidr_block                      = "${cidrsubnet(var.host_cidr, 4, count.index)}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.network.ipv6_cidr_block, 8, count.index)}"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false

  tags = "${map("Name", "${var.cluster_name}-private-${count.index}")}"
}

resource "aws_route_table_association" "public" {
  count          = 0
  route_table_id = ""
  subnet_id      = ""
}

resource "aws_route_table_association" "private" {
  count = "${length(data.aws_availability_zones.all.names)}"

  route_table_id = "${aws_route_table.default.id}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
}
