# Copy to terraform.tfvars — DO NOT commit the actual tfvars file

aws_region           = "us-east-1"
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
kubernetes_version   = "1.29"
node_instance_types  = ["t3.medium"]
node_desired_size    = 2
node_min_size        = 1
node_max_size        = 3
node_volume_size     = 100
github_org           = "ChinthanaHub"
github_repo          = "CSE_PA_Final_002"
alert_email          = "thanachin74@gmail.com"
