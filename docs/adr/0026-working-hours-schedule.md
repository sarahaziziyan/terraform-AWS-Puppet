# 0026. Run the web servers only in working hours

- **Status:** Accepted
- **Date:** 2026-11-20
- **Deciders:** Sarah Aziziyan
- **Supersedes:** —
- **Superseded by:** —
- **Commits:** —

## Context

The site is only needed in working hours (Monday to Friday, 09:00 to 18:00, UTC+8). Web servers running at night and at weekends cost money and serve nobody. The schedule must be easy to turn off.

## Decision

- The ASG module has two scheduled actions, created only when `schedule_enabled` is true (root: `web_schedule_enabled`):
  - **start** (`working-hours-start`): sets min to `asg_min_size` and desired to `asg_desired_capacity`.
  - **stop** (`working-hours-stop`): sets min and desired to 0, which terminates every server.
  - Neither changes max (`-1`), so `asg_max_size` stays under Terraform's control.
- Days, start, stop and time zone are root variables (`web_schedule_days`, `web_schedule_start`, `web_schedule_stop`, `web_schedule_time_zone`), required in `terraform.tfvars` (no defaults, so the working hours are always a visible choice); `terraform_example_tfvars` uses `MON-FRI`, `09:00`, `18:00`, `Asia/Singapore`. The module turns the `HH:MM` times into cron expressions and validates the inputs.
- The ASG ignores `min_size` after creation (`ignore_changes = [desired_capacity, min_size]`). Otherwise an apply at night would reset min to `asg_min_size` and start the servers. `ignore_changes` cannot depend on a variable, so this holds even when the schedule is off.

## Considered options

- **One ASG that always ignores `min_size`** (chosen): little code, and turning the schedule on or off never replaces servers.
- **Two ASG resources, one picked by the switch**: with the schedule off, Terraform manages `min_size` as before. But flipping the switch replaces the web servers (about 10 minutes of 503s), and the ASG block is duplicated.
- **Leave `min_size` managed**: simplest, but any apply outside working hours starts the servers until the next stop.

## Consequences

### Good

- No web servers run outside working hours.
- One setting in `terraform.tfvars` turns the schedule on or off; times, days and time zone are settings too.

### Bad

- The site answers 503 outside working hours (CloudFront may serve cached pages for up to 5 minutes).
- The site is up about 10 minutes after the start time: servers boot and run Puppet first.
- A change to `asg_min_size` reaches an existing ASG only at the next start action, and never while the schedule is off (known issue 23).
- An ASG created outside working hours starts at the normal size and runs until the next stop.
- The Puppet master, the ALB and CloudFront keep running and costing money at night.
- A new set of servers every working day means old Puppet certificates pile up on the master faster ([0010](0010-instance-id-as-certname.md), [TODO.md](../TODO.md)).

## Links

- [modules/aws/module_aws_asg/main.tf](../../modules/aws/module_aws_asg/main.tf), [0015](0015-lifecycle-ignore-changes.md), [0025](0025-target-tracking-scaling.md), [DEPLOYMENT.md](../DEPLOYMENT.md)
