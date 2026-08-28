variable "folder_id" {
    type = string
}

variable "db_login" {
  type        = string
  sensitive   = true
}

variable "db_password" {
  type        = string
  sensitive   = true
}
