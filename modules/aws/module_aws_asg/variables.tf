variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ASG (at least two AZs)"
}

variable "launch_template_id" {
  type        = string
  description = "ID of the launch template used by the ASG"
}

variable "launch_template_version" {
  type        = number
  description = "Launch template version the ASG uses. Pass the template's latest_version: a new number starts a rolling instance refresh"
}

variable "target_group_arns" {
  type        = list(string)
  description = "Target group ARNs the ASG registers instances with"
}

variable "min_size" {
  type        = number
  description = "Minimum number of instances in working hours. Used when the ASG is created and by the schedule's start action; ignored by later applies (ADR 0026)"
}

variable "desired_capacity" {
  type        = number
  description = "Number of instances when the ASG is first created. Ignored afterwards: the scaling policy owns the running count"
}

variable "max_size" {
  type        = number
  description = "Maximum number of instances in ASG"
}

variable "cpu_target" {
  type        = number
  description = "Average CPU % the target tracking policy keeps the group at: it adds nodes above it and removes them below it"

  validation {
    condition     = var.cpu_target > 0 && var.cpu_target < 100
    error_message = "cpu_target must be a percentage between 0 and 100 (exclusive)."
  }
}

# Working-hours schedule (ADR 0026)
variable "schedule_enabled" {
  type        = bool
  description = "Scale the group to 0 servers outside working hours. false = servers run all the time"
}

variable "schedule_time_zone" {
  type        = string
  description = "IANA time zone the schedule times are in, for example Asia/Singapore"

  validation {
    condition     = length(trimspace(var.schedule_time_zone)) > 0
    error_message = "schedule_time_zone must be an IANA time zone name, for example Asia/Singapore."
  }
}

variable "schedule_days" {
  type        = string
  description = "Days the servers run, as a cron day-of-week field: MON-FRI, MON-SAT, MON,WED,FRI or * (every day)"

  validation {
    condition     = can(regex("^(\\*|(MON|TUE|WED|THU|FRI|SAT|SUN)([-,](MON|TUE|WED|THU|FRI|SAT|SUN))*)$", var.schedule_days))
    error_message = "schedule_days must use MON to SUN joined by - or , (for example MON-FRI), or * for every day."
  }
}

variable "schedule_start" {
  type        = string
  description = "Time (HH:MM, 24-hour) the servers start each working day. They serve the site about 10 minutes later"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.schedule_start))
    error_message = "schedule_start must be a 24-hour time HH:MM, for example 09:00."
  }
}

variable "schedule_stop" {
  type        = string
  description = "Time (HH:MM, 24-hour) all servers are terminated each working day"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.schedule_stop))
    error_message = "schedule_stop must be a 24-hour time HH:MM, for example 18:00."
  }
}
