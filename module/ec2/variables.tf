variable "env_name" {
    default = "ec2"
}
variable "instance_name" {}
variable "instance_type" {
  default = "t2.nano"
}
variable "ami" {
  default = "ami-0a37aadea3f79d3c3"
}
variable "created_by" {
  default = "terraform"
}
variable "key_name" {
  default = "ec2-keypair"
}