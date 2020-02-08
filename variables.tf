variable "alicloud_access_key" {
  default = "XXXXXXXXXXXXXXXXXXXXXXXX"
}

variable "alicloud_secret_key" {
  default = "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"
}

variable "alicloud_region" {
  default = "ap-northeast-1"
}

variable "ssh_public_key_file" {
  description = "SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_file" {
  description = "SSH private key file"
  default     = "~/.ssh/id_rsa"
}
