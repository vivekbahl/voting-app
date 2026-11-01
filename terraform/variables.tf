variable "project_id" {
  description = "GCP project to deploy into."
  type        = string
  default     = "terraform-infra-qa"
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "voting-app"
}

variable "option_a" {
  description = "Label for the first voting option."
  type        = string
  default     = "Cats"
}

variable "option_b" {
  description = "Label for the second voting option."
  type        = string
  default     = "Dogs"
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "redis_memory_size_gb" {
  description = "Memorystore Redis capacity in GB."
  type        = number
  default     = 1
}

variable "web_max_instances" {
  description = "Max Cloud Run instances for the vote and result services."
  type        = number
  default     = 3
}

variable "allow_public_access" {
  description = "Grant allUsers invoker on vote and result. Set false if an org policy blocks public services."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Protect the Cloud SQL instance from deletion. Set false for throwaway environments."
  type        = bool
  default     = false
}
