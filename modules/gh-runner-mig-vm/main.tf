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

locals {
  network_name    = var.create_network ? google_compute_network.gh-network[0].self_link : var.network_name
  subnet_name     = var.create_subnetwork ? google_compute_subnetwork.gh-subnetwork[0].self_link : var.subnet_name
  service_account = var.service_account == "" ? google_service_account.runner_service_account[0].email : var.service_account
  startup_script  = var.startup_script == "" ? file("${path.module}/scripts/startup.sh") : var.startup_script
  shutdown_script = var.shutdown_script == "" ? file("${path.module}/scripts/shutdown.sh") : var.shutdown_script
}

/*****************************************
  Optional Runner Networking
 *****************************************/
resource "google_compute_network" "gh-network" {
  count                   = var.create_network ? 1 : 0
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "gh-subnetwork" {
  count         = var.create_subnetwork ? 1 : 0
  project       = var.project_id
  name          = var.subnet_name
  ip_cidr_range = var.subnet_ip
  region        = var.region
  network       = local.network_name
}

resource "google_compute_router" "default" {
  count   = var.create_network ? 1 : 0
  name    = "${var.network_name}-router"
  network = google_compute_network.gh-network[0].self_link
  region  = var.region
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  count                              = var.create_network ? 1 : 0
  project                            = var.project_id
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.default[0].name
  region                             = google_compute_router.default[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

/*****************************************
  IAM Bindings GCE SVC
 *****************************************/

resource "google_service_account" "runner_service_account" {
  count        = var.service_account == "" ? 1 : 0
  project      = var.project_id
  account_id   = "runner-service-account"
  display_name = "Github Runner GCE Service Account"
}

/*****************************************
  Runner Secrets
 *****************************************/
resource "google_secret_manager_secret" "gh-secret" {
  provider  = google-beta
  project   = var.project_id
  secret_id = "gh-token"

  labels = {
    label = "gh-token"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}
resource "google_secret_manager_secret_version" "gh-secret-version" {
  provider = google-beta
  secret   = google_secret_manager_secret.gh-secret.id
  secret_data = jsonencode({
    "REPO_NAME"    = var.repo_name
    "REPO_OWNER"   = var.repo_owner
    "GITHUB_TOKEN" = var.gh_token
    "LABELS"       = join(",", var.gh_runner_labels)
  })
}


resource "google_secret_manager_secret_iam_member" "gh-secret-member" {
  provider  = google-beta
  project   = var.project_id
  secret_id = google_secret_manager_secret.gh-secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.service_account}"
}

/*****************************************
  Runner GCE Instance Template
 *****************************************/
locals {
  instance_name = "gh-runner-vm"
}


module "mig_template" {
  source             = "terraform-google-modules/vm/google//modules/instance_template"
  version            = "~> 13.0"
  project_id         = var.project_id
  machine_type       = var.machine_type
  network            = local.network_name
  subnetwork         = local.subnet_name
  region             = var.region
  subnetwork_project = var.subnetwork_project != "" ? var.subnetwork_project : var.project_id
  service_account = {
    email = local.service_account
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
  disk_size_gb         = 100
  disk_type            = "pd-ssd"
  auto_delete          = true
  name_prefix          = "gh-runner"
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project
  startup_script       = local.startup_script
  source_image         = var.source_image
  metadata = merge({
    "secret-id" = google_secret_manager_secret_version.gh-secret-version.name
    }, {
    "shutdown-script" = local.shutdown_script
  }, var.custom_metadata)
  tags = concat(["gh-runner-vm"], var.instance_tags)
}
/*****************************************
  Runner MIG
 *****************************************/
module "mig" {
  source            = "terraform-google-modules/vm/google//modules/mig"
  version           = "~> 13.0"
  project_id        = var.project_id
  hostname          = local.instance_name
  region            = var.region
  instance_template = module.mig_template.self_link

  /* autoscaler - disabled when using custom autoscaler with schedule */
  autoscaling_enabled = var.enable_schedule ? false : true
  min_replicas        = var.min_replicas
  max_replicas        = var.max_replicas
  cooldown_period     = var.cooldown_period
}

/*****************************************
  Custom Autoscaler with Scaling Schedule
 *****************************************/
locals {
  # Calculate duration in seconds based on working hours
  working_hours_duration = (var.schedule_working_hours_end - var.schedule_working_hours_start) * 3600
  # Calculate off-hours duration (24 hours - working hours duration)
  off_hours_duration = (24 - (var.schedule_working_hours_end - var.schedule_working_hours_start)) * 3600
}

resource "google_compute_region_autoscaler" "runner_autoscaler" {
  count   = var.enable_schedule ? 1 : 0
  project = var.project_id
  name    = "${local.instance_name}-autoscaler"
  region  = var.region
  target  = module.mig.instance_group_manager.id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = var.cooldown_period

    # CPU-based autoscaling
    dynamic "cpu_utilization" {
      for_each = var.autoscaling_cpu_enabled ? [1] : []
      content {
        target = var.autoscaling_cpu_target
      }
    }

    # Load balancing-based autoscaling
    dynamic "load_balancing_utilization" {
      for_each = var.autoscaling_load_balancing_enabled ? [1] : []
      content {
        target = var.autoscaling_load_balancing_target
      }
    }

    # Custom metric-based autoscaling
    dynamic "metric" {
      for_each = var.autoscaling_metric
      content {
        name   = metric.value.name
        target = metric.value.target
        type   = metric.value.type
      }
    }

    # Scale to configured replicas during working hours
    scaling_schedules {
      name                  = "scale-working-hours"
      description           = "Scale to ${var.schedule_working_hours_min_replicas} replicas during working hours (${var.schedule_working_hours_start}:00-${var.schedule_working_hours_end}:00)"
      min_required_replicas = var.schedule_working_hours_min_replicas
      schedule              = "0 ${var.schedule_working_hours_start} * * ${var.schedule_working_days}"
      time_zone             = var.schedule_timezone
      duration_sec          = local.working_hours_duration
    }

    # Scale to configured replicas after working hours
    scaling_schedules {
      name                  = "scale-off-hours"
      description           = "Scale to ${var.schedule_off_hours_min_replicas} replicas during off-hours"
      min_required_replicas = var.schedule_off_hours_min_replicas
      schedule              = "0 ${var.schedule_working_hours_end} * * ${var.schedule_working_days}"
      time_zone             = var.schedule_timezone
      duration_sec          = local.off_hours_duration
    }

    # Scale to configured replicas on weekends (if working_days doesn't cover all days)
    dynamic "scaling_schedules" {
      for_each = var.schedule_working_days != "*" ? [1] : []
      content {
        name                  = "scale-weekends"
        description           = "Scale to ${var.schedule_weekend_min_replicas} replicas on weekends"
        min_required_replicas = var.schedule_weekend_min_replicas
        schedule              = "0 0 * * 6"
        time_zone             = var.schedule_timezone
        duration_sec          = 172800 # 48 hours (Saturday and Sunday)
      }
    }
  }
}
