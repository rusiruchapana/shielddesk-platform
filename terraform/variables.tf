variable "subscription_id" { type = string }
variable "location" { type = string default = "australiaeast" }
variable "prefix" { type = string default = "shielddesk" }
variable "vm_size" { type = string default = "Standard_D2s_v5" }
variable "node_count" { type = number default = 1 validation {condition=var.node_count>=1 && var.node_count<=3 error_message="Keep lab node count between 1 and 3."} }
variable "create_user_pool" { type = bool default = false }
variable "owner" { type = string default = "learning" }
