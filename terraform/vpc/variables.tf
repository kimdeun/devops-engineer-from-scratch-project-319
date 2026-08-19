variable "vpc_name" {
    type = string
}

variable "subnets" {
  type = map(object({
    zone   = string
    cidr   = string
    public = bool
  }))
}

variable "folder_id" {
    type = string
}

variable "bucket_name" {
    type = string
}

variable "cloud_id" {
    type = string
}
