# Network Load Balancer for apiservers and ingress
resource "aws_lb" "nlb" {
  name               = "${var.cluster_name}-nlb"
  load_balancer_type = "network"
  internal           = false

  subnets = ["${aws_subnet.private.*.id}"]

  enable_cross_zone_load_balancing = true
}
