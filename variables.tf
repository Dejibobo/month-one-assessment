variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "techcorp"
}

variable "instance_type" {
  description = "EC2 instance type for servers"
  type        = string
  default     = "t3.micro"
}

variable "admin_ip" {
  description = "Public IP allowed to SSH into bastion"
  type        = string
  default     = "105.112.216.234/32" # replace with your IP
}
