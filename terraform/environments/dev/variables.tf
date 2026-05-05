variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.32"
}


variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "ChinthanaHub"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "CSE_PA_Final_002"
}

variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
  default     = ""
}
