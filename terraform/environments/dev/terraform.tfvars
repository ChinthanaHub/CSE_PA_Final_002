# Copy this file to terraform.tfvars and fill in your values
# DO NOT commit terraform.tfvars — it is in .gitignore

aws_region           = "us-east-1"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
kubernetes_version   = "1.30"
node_instance_types  = ["t3.micro"]
capacity_type        = "ON_DEMAND"
node_desired_size    = 1
node_min_size        = 1
node_max_size        = 2
node_volume_size     = 50
github_org           = "ChinthanaHub"
github_repo          = "CSE_PA_Final_002"
alert_email          = "thanachin74@gmail.com"


