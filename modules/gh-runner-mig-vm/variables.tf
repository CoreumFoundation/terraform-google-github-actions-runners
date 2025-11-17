/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  type        = string
  description = "The project id to deploy Github Runner"
}
variable "region" {
  type        = string
  description = "The GCP region to deploy instances into"
  default     = "us-east4"
}

variable "network_name" {
  type        = string
  description = "Name for the VPC network"
  default     = "gh-runner-network"
}

variable "create_network" {
  type        = bool
  description = "When set to true, VPC,router and NAT will be auto created"
  default     = true
}

variable "subnetwork_project" {
  type        = string
  description = "The ID of the project in which the subnetwork belongs. If it is not provided, the project_id is used."
  default     = ""
}

variable "subnet_ip" {
  type        = string
  description = "IP range for the subnet"
  default     = "10.10.10.0/24"
}

variable "create_subnetwork" {
  type        = bool
  description = "Whether to create subnetwork or use the one provided via subnet_name"
  default     = true
}

variable "subnet_name" {
  type        = string
  description = "Name for the subnet"
  default     = "gh-runner-subnet"
}

variable "repo_name" {
  type        = string
  description = "Name of the repo for the Github Action"
  default     = ""
}

variable "repo_owner" {
  type        = string
  description = "Owner of the repo for the Github Action"
}

variable "gh_runner_labels" {
  type        = set(string)
  description = "GitHub runner labels to attach to the runners. Docs: https://docs.github.com/en/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners"
  default     = []
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of runner instances"
  default     = 2
}

variable "max_replicas" {
  type        = number
  default     = 10
  description = "Maximum number of runner instances"
}

variable "gh_token" {
  type        = string
  description = "Github token that is used for generating Self Hosted Runner Token"
}

variable "service_account" {
  description = "Service account email address"
  type        = string
  default     = ""
}

variable "machine_type" {
  type        = string
  description = "The GCP machine type to deploy"
  default     = "n1-standard-1"
}

variable "source_image_family" {
  type        = string
  description = "Source image family. If neither source_image nor source_image_family is specified, defaults to the latest public Ubuntu image."
  default     = "ubuntu-1804-lts"
}

variable "source_image_project" {
  type        = string
  description = "Project where the source image comes from"
  default     = "ubuntu-os-cloud"
}

variable "source_image" {
  type        = string
  description = "Source disk image. If neither source_image nor source_image_family is specified, defaults to the latest public CentOS image."
  default     = ""
}

variable "startup_script" {
  type        = string
  description = "User startup script to run when instances spin up"
  default     = ""
}

variable "shutdown_script" {
  type        = string
  description = "User shutdown script to run when instances shutdown"
  default     = ""
}

variable "custom_metadata" {
  type        = map(any)
  description = "User provided custom metadata"
  default     = {}
}

variable "cooldown_period" {
  description = "The number of seconds that the autoscaler should wait before it starts collecting information from a new instance."
  type        = number
  default     = 60
}

variable "enable_schedule" {
  description = "Enable autoscaling schedule. When enabled, scales based on configured schedule parameters."
  type        = bool
  default     = false
}

variable "schedule_timezone" {
  description = "The timezone for the scaling schedule. Use IANA timezone format (e.g., 'Europe/Warsaw' for CEST)."
  type        = string
  default     = "Europe/Warsaw"
}

variable "schedule_working_hours_start" {
  description = "Start hour for working hours (0-23). Uses 24-hour format."
  type        = number
  default     = 7
  validation {
    condition     = var.schedule_working_hours_start >= 0 && var.schedule_working_hours_start <= 23
    error_message = "Start hour must be between 0 and 23."
  }
}

variable "schedule_working_hours_end" {
  description = "End hour for working hours (0-23). Uses 24-hour format."
  type        = number
  default     = 19
  validation {
    condition     = var.schedule_working_hours_end >= 0 && var.schedule_working_hours_end <= 23
    error_message = "End hour must be between 0 and 23."
  }
}

variable "schedule_working_days" {
  description = "Working days in cron format (e.g., '1-5' for Monday-Friday, '1,3,5' for Mon/Wed/Fri, '*' for all days)."
  type        = string
  default     = "1-5"
}

variable "schedule_working_hours_min_replicas" {
  description = "Minimum number of replicas during working hours."
  type        = number
  default     = 1
}

variable "schedule_off_hours_min_replicas" {
  description = "Minimum number of replicas during off-hours."
  type        = number
  default     = 0
}

variable "schedule_weekend_min_replicas" {
  description = "Minimum number of replicas during weekends. Set to null to disable separate weekend schedule."
  type        = number
  default     = 0
}

variable "autoscaling_cpu_enabled" {
  description = "Enable CPU-based autoscaling. When enabled, instances will scale based on CPU utilization."
  type        = bool
  default     = true
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization for autoscaling (0.0 - 1.0). For example, 0.6 means 60% CPU utilization."
  type        = number
  default     = 0.6
  validation {
    condition     = var.autoscaling_cpu_target > 0 && var.autoscaling_cpu_target <= 1.0
    error_message = "CPU target must be between 0.0 and 1.0."
  }
}

variable "autoscaling_load_balancing_enabled" {
  description = "Enable load balancing utilization-based autoscaling."
  type        = bool
  default     = false
}

variable "autoscaling_load_balancing_target" {
  description = "Target load balancing utilization for autoscaling (0.0 - 1.0)."
  type        = number
  default     = 0.8
  validation {
    condition     = var.autoscaling_load_balancing_target > 0 && var.autoscaling_load_balancing_target <= 1.0
    error_message = "Load balancing target must be between 0.0 and 1.0."
  }
}

variable "autoscaling_metric" {
  description = "Custom metric-based autoscaling configuration. List of maps with keys: name, target, type (GAUGE or DELTA_PER_SECOND or DELTA_PER_MINUTE)."
  type = list(object({
    name   = string
    target = number
    type   = string
  }))
  default = []
}

variable "instance_tags" {
  type        = list(string)
  description = "Additional tags to add to the instances"
  default     = []
}

variable "spot" {
  type        = bool
  description = "Provision a SPOT instance"
  default     = false
}

variable "spot_instance_termination_action" {
  description = "Action to take when Compute Engine preempts a Spot VM."
  type        = string
  default     = "STOP"
}

variable "disk_size_gb" {
  type        = number
  description = "Instance disk size in GB"
  default     = 100
}

variable "disk_type" {
  type        = string
  description = "Instance disk type, can be either pd-ssd, local-ssd, or pd-standard"
  default     = "pd-ssd"
}
