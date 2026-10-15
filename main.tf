module "ec2" {
  source        = "./module/ec2"
  count         = 4
  instance_name = "online-course-${count.index}"
}