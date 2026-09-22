variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "multi-cloud-capstone"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "listener_port" {
  type    = number
  default = 8090
}

variable "image_tag" {
  type = string
}
