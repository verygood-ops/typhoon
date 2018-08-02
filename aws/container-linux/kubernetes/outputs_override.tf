output "subnet_ids" {
  value       = ["${aws_subnet.private.*.id}"]
  description = "List of subnet IDs for creating worker instances"
}
