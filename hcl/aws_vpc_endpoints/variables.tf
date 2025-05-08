variable "vpc_id" {
  type        = string
  description = "ID of the exiting VPC"
  default     = "platformwale"
}

variable "region" {  
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}