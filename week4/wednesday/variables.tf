variable "region" {
  description = "AWS region where the infrastructure will be created."
  type        = string
  default     = "af-south-1"
}

variable "availabiliity_zone" {
  description = "Availability Zone for the EC2 instance"
  type        = string
  default     = "af-south-1a"
}

variable "instance_type" {
  description = "EC2 instance type for the server."
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Environment tag applied to all resources."
  type        = string
  default     = "staging"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair used for SSH access"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the EC2 instance and security group will be created."
  type        = string
}

variable "my_ip" {
  description = "Public IP address allowed to SSH to the instance in CIDR notation"
  type        = string
}
