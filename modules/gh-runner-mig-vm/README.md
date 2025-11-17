## Self Hosted Runners on Managed Instance Group

This module handles the opinionated creation of infrastructure necessary to deploy Github Self Hosted Runners on MIG.

This includes:

- Enabling necessary APIs
- VPC
- NAT & Cloud Router
- Service Account for MIG
- MIG Instance Template
- MIG Instance Manager
- FW Rules
- Secret Manager Secret

Below are some examples:

### [Simple Self Hosted Runner](../../examples/gh-runner-mig-native-simple/README.md)

This example shows how to deploy a MIG Self Hosted Runner bootstrapped using startup scripts.

### [Simple Self Hosted Runner](../../examples/gh-runner-mig-native-packer/README.md)

This example shows how to deploy a MIG Self Hosted Runner with an image pre-baked using Packer.

## Autoscaling

This module supports both metric-based and schedule-based autoscaling to automatically scale runners based on load and time.

### Metric-Based Autoscaling

The autoscaler can scale instances based on various metrics:

- **CPU Utilization** (default: enabled at 60% target) - Scales based on average CPU usage across instances
- **Load Balancing Utilization** (default: disabled) - Scales based on load balancer serving capacity
- **Custom Metrics** - Define your own Cloud Monitoring metrics for autoscaling

These metrics work in combination with schedule-based scaling to provide intelligent, cost-effective scaling.

### Schedule-Based Autoscaling

This module supports fully configurable autoscaling schedules to automatically scale runners based on time. This is useful for cost optimization when runners are only needed during specific hours.

### Default Schedule
When `enable_schedule = true`, the default schedule is:
- **Working hours (7AM-7PM CEST, Monday-Friday)**: Scales to 1 instance
- **After hours and weekends**: Scales down to 0 instances

### Customization Options
All schedule parameters are configurable:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `schedule_timezone` | IANA timezone (e.g., 'Europe/Warsaw', 'America/New_York') | `"Europe/Warsaw"` |
| `schedule_working_hours_start` | Start hour (0-23, 24-hour format) | `7` |
| `schedule_working_hours_end` | End hour (0-23, 24-hour format) | `19` |
| `schedule_working_days` | Cron format days (e.g., '1-5', '1,3,5', '\*') | `"1-5"` |
| `schedule_working_hours_min_replicas` | Min replicas during working hours | `1` |
| `schedule_off_hours_min_replicas` | Min replicas during off-hours | `0` |
| `schedule_weekend_min_replicas` | Min replicas on weekends | `0` |

### Examples

**Basic usage with defaults (CPU autoscaling + schedule 7AM-7PM CEST, Mon-Fri):**
```hcl
module "gh_runner_mig" {
  source          = "./modules/gh-runner-mig-vm"
  enable_schedule = true
  min_replicas    = 0
  max_replicas    = 10

  # CPU autoscaling is enabled by default at 60% target
  autoscaling_cpu_enabled = true
  autoscaling_cpu_target  = 0.6  # 60% CPU

  # ... other required variables
}
```

**Custom schedule (9AM-6PM EST, Mon-Fri, 2 instances during work):**
```hcl
module "gh_runner_mig" {
  source                              = "./modules/gh-runner-mig-vm"
  enable_schedule                     = true
  schedule_timezone                   = "America/New_York"
  schedule_working_hours_start        = 9
  schedule_working_hours_end          = 18
  schedule_working_hours_min_replicas = 2
  schedule_off_hours_min_replicas     = 0
  schedule_weekend_min_replicas       = 0
  min_replicas                        = 0
  max_replicas                        = 10
  # ... other required variables
}
```

**24/7 with reduced capacity at night:**
```hcl
module "gh_runner_mig" {
  source                              = "./modules/gh-runner-mig-vm"
  enable_schedule                     = true
  schedule_working_days               = "*"  # All days
  schedule_working_hours_start        = 8
  schedule_working_hours_end          = 20
  schedule_working_hours_min_replicas = 3
  schedule_off_hours_min_replicas     = 1
  min_replicas                        = 1
  max_replicas                        = 10
  # ... other required variables
}
```

**Custom CPU target and additional metrics:**
```hcl
module "gh_runner_mig" {
  source          = "./modules/gh-runner-mig-vm"
  enable_schedule = true

  # Aggressive CPU-based scaling
  autoscaling_cpu_enabled = true
  autoscaling_cpu_target  = 0.7  # Scale when CPU reaches 70%

  # Custom metrics (e.g., queue depth)
  autoscaling_metric = [
    {
      name   = "pubsub.googleapis.com/subscription/num_undelivered_messages"
      target = 100
      type   = "GAUGE"
    }
  ]

  min_replicas = 0
  max_replicas = 20
  # ... other required variables
}
```

**Schedule-only autoscaling (no CPU-based scaling):**
```hcl
module "gh_runner_mig" {
  source          = "./modules/gh-runner-mig-vm"
  enable_schedule = true

  # Disable CPU autoscaling, rely only on schedule
  autoscaling_cpu_enabled = false

  min_replicas = 0
  max_replicas = 5
  # ... other required variables
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| autoscaling\_cpu\_enabled | Enable CPU-based autoscaling. When enabled, instances will scale based on CPU utilization. | `bool` | `true` | no |
| autoscaling\_cpu\_target | Target CPU utilization for autoscaling (0.0 - 1.0). For example, 0.6 means 60% CPU utilization. | `number` | `0.6` | no |
| autoscaling\_load\_balancing\_enabled | Enable load balancing utilization-based autoscaling. | `bool` | `false` | no |
| autoscaling\_load\_balancing\_target | Target load balancing utilization for autoscaling (0.0 - 1.0). | `number` | `0.8` | no |
| autoscaling\_metric | Custom metric-based autoscaling configuration. List of maps with keys: name, target, type (GAUGE or DELTA\_PER\_SECOND or DELTA\_PER\_MINUTE). | `list(object({ name = string, target = number, type = string }))` | `[]` | no |
| cooldown\_period | The number of seconds that the autoscaler should wait before it starts collecting information from a new instance. | `number` | `60` | no |
| create\_network | When set to true, VPC,router and NAT will be auto created | `bool` | `true` | no |
| enable\_schedule | Enable autoscaling schedule. When enabled, scales based on configured schedule parameters. | `bool` | `false` | no |
| create\_subnetwork | Whether to create subnetwork or use the one provided via subnet\_name | `bool` | `true` | no |
| custom\_metadata | User provided custom metadata | `map(any)` | `{}` | no |
| disk\_size\_gb | Instance disk size in GB | `number` | `100` | no |
| disk\_type | Instance disk type, can be either pd-ssd, local-ssd, or pd-standard | `string` | `"pd-ssd"` | no |
| gh\_runner\_labels | GitHub runner labels to attach to the runners. Docs: https://docs.github.com/en/actions/hosting-your-own-runners/using-labels-with-self-hosted-runners | `set(string)` | `[]` | no |
| gh\_token | Github token that is used for generating Self Hosted Runner Token | `string` | n/a | yes |
| instance\_tags | Additional tags to add to the instances | `list(string)` | `[]` | no |
| machine\_type | The GCP machine type to deploy | `string` | `"n1-standard-1"` | no |
| max\_replicas | Maximum number of runner instances | `number` | `10` | no |
| min\_replicas | Minimum number of runner instances | `number` | `2` | no |
| network\_name | Name for the VPC network | `string` | `"gh-runner-network"` | no |
| project\_id | The project id to deploy Github Runner | `string` | n/a | yes |
| region | The GCP region to deploy instances into | `string` | `"us-east4"` | no |
| repo\_name | Name of the repo for the Github Action | `string` | `""` | no |
| repo\_owner | Owner of the repo for the Github Action | `string` | n/a | yes |
| schedule\_off\_hours\_min\_replicas | Minimum number of replicas during off-hours. | `number` | `0` | no |
| schedule\_timezone | The timezone for the scaling schedule. Use IANA timezone format (e.g., 'Europe/Warsaw' for CEST). | `string` | `"Europe/Warsaw"` | no |
| schedule\_weekend\_min\_replicas | Minimum number of replicas during weekends. Set to null to disable separate weekend schedule. | `number` | `0` | no |
| schedule\_working\_days | Working days in cron format (e.g., '1-5' for Monday-Friday, '1,3,5' for Mon/Wed/Fri, '\*' for all days). | `string` | `"1-5"` | no |
| schedule\_working\_hours\_end | End hour for working hours (0-23). Uses 24-hour format. | `number` | `19` | no |
| schedule\_working\_hours\_min\_replicas | Minimum number of replicas during working hours. | `number` | `1` | no |
| schedule\_working\_hours\_start | Start hour for working hours (0-23). Uses 24-hour format. | `number` | `7` | no |
| service\_account | Service account email address | `string` | `""` | no |
| shutdown\_script | User shutdown script to run when instances shutdown | `string` | `""` | no |
| source\_image | Source disk image. If neither source\_image nor source\_image\_family is specified, defaults to the latest public CentOS image. | `string` | `""` | no |
| source\_image\_family | Source image family. If neither source\_image nor source\_image\_family is specified, defaults to the latest public Ubuntu image. | `string` | `"ubuntu-1804-lts"` | no |
| source\_image\_project | Project where the source image comes from | `string` | `"ubuntu-os-cloud"` | no |
| spot | Provision a SPOT instance | `bool` | `false` | no |
| spot\_instance\_termination\_action | Action to take when Compute Engine preempts a Spot VM. | `string` | `"STOP"` | no |
| startup\_script | User startup script to run when instances spin up | `string` | `""` | no |
| subnet\_ip | IP range for the subnet | `string` | `"10.10.10.0/24"` | no |
| subnet\_name | Name for the subnet | `string` | `"gh-runner-subnet"` | no |
| subnetwork\_project | The ID of the project in which the subnetwork belongs. If it is not provided, the project\_id is used. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| autoscaler\_name | The name of the autoscaler (if schedule is enabled) |
| autoscaler\_target | The target MIG for the autoscaler (if schedule is enabled) |
| mig\_instance\_group | The instance group url of the created MIG |
| mig\_instance\_template | The name of the MIG Instance Template |
| mig\_name | The name of the MIG |
| network\_name | Name of VPC |
| service\_account | Service account email for GCE |
| subnet\_name | Name of VPC |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

Before this module can be used on a project, you must ensure that the following pre-requisites are fulfilled:

1. Required APIs are activated

    ```
    "iam.googleapis.com",
    "compute.googleapis.com",
    "storage-component.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    ```
