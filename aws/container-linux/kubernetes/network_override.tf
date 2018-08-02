resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.all.names)}"

  vpc_id            = "${aws_vpc.network.id}"
  availability_zone = "${data.aws_availability_zones.all.names[count.index]}"

  cidr_block                      = "${cidrsubnet(var.host_cidr, 4, length(aws_subnet.public.*.id) + count.index)}"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false

  tags = "${map("Name", "${var.cluster_name}-private-${count.index}")}"
}

resource "aws_eip" "nat" {
  count = "${length(data.aws_availability_zones.all.names)}"
  vpc   = true

  #depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "nat" {
  count         = "${length(data.aws_availability_zones.all.names)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"

  #depends_on    = ["aws_internet_gateway.gw"]
}

resource "aws_route_table" "private" {
  count  = "${length(data.aws_availability_zones.all.names)}"
  vpc_id = "${aws_vpc.network.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${element(aws_nat_gateway.nat.*.id, count.index)}"
  }

  tags = "${map("Name", "${var.cluster_name}")}"
}

resource "aws_route_table_association" "private" {
  count = "${length(data.aws_availability_zones.all.names)}"

  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
}
