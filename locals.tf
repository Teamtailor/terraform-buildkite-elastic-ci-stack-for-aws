locals {
  # AWS managed policies for container registry access
  ecr_policy_arns = {
    none                  = ""
    readonly              = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    readonly-pullthrough  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    poweruser             = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    poweruser-pullthrough = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    full                  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  }

  # VPC, subnet, and security group creation flags
  create_vpc            = var.vpc_id == ""
  create_security_group = length(var.security_group_ids) == 0
  use_custom_azs        = var.availability_zones != ""

  # Secrets and artifacts bucket settings
  create_secrets_bucket = var.enable_secrets_plugin && var.secrets_bucket == ""
  secrets_bucket_sse    = local.create_secrets_bucket && var.secrets_bucket_encryption
  use_existing_secrets  = var.secrets_bucket != ""
  has_secrets_bucket    = local.create_secrets_bucket || local.use_existing_secrets
  use_artifacts_bucket  = var.artifacts_bucket != ""

  # Instance role, permissions boundary, and policy settings
  use_custom_iam_role              = var.instance_role_arn != ""
  use_custom_role_name             = var.instance_role_name != ""
  use_custom_instance_profile_name = var.instance_profile_name != ""
  use_permissions_boundary         = var.instance_role_permissions_boundary_arn != ""

  custom_role_name = local.use_custom_iam_role ? element(split("/", var.instance_role_arn), length(split("/", var.instance_role_arn)) - 1) : ""

  use_custom_scaler_lambda_role         = var.scaler_lambda_role_arn != ""
  use_custom_asg_process_suspender_role = var.asg_process_suspender_role_arn != ""
  use_custom_stop_buildkite_agents_role = var.stop_buildkite_agents_role_arn != ""

  # Parse comma-separated role tags into list
  role_tag_list  = compact(split(",", var.instance_role_tags))
  role_tag_count = length(local.role_tag_list)

  use_managed_policies = length(var.managed_policy_arns) > 0


  # Image ID selection and parameter store settings
  use_custom_ami    = var.image_id != ""
  use_ami_parameter = var.image_id_parameter != ""

  # Region-specific AMI IDs by distribution and architecture
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-07cabf089a4de9788", linuxarm64 = "ami-0bcf3a9f1ac9de8d2", windows = "ami-0c0645557d2f7b02b", ubuntu2404amd64 = "ami-004e3b3fb4999ce0d", ubuntu2404arm64 = "ami-09ae47a5ada7460fa" }
    us-east-2                    = { linuxamd64 = "ami-0f18f45154b1ac4db", linuxarm64 = "ami-06647ded5ed713574", windows = "ami-09d97c8d9d52a8ff9", ubuntu2404amd64 = "ami-00dee110da2810fcf", ubuntu2404arm64 = "ami-0c453361469682cef" }
    us-west-1                    = { linuxamd64 = "ami-01bc0a9071a6263de", linuxarm64 = "ami-0fde87f66fa7cb730", windows = "ami-0f1894f880fde5d85", ubuntu2404amd64 = "ami-02db1dda294fd899e", ubuntu2404arm64 = "ami-0914ca55bcd2a2272" }
    us-west-2                    = { linuxamd64 = "ami-0aee5f1177e60fba6", linuxarm64 = "ami-0310a60094190d555", windows = "ami-0af2bfb45a314bf5d", ubuntu2404amd64 = "ami-00b98cf6d4204cb32", ubuntu2404arm64 = "ami-0f08e76d314525e56" }
    af-south-1                   = { linuxamd64 = "ami-050e2e37f113c0bdf", linuxarm64 = "ami-0190a896c25ccdd28", windows = "ami-0b5079e3287622876", ubuntu2404amd64 = "ami-0b6eb49d2051a71de", ubuntu2404arm64 = "ami-09e49c1a6327906fb" }
    ap-east-1                    = { linuxamd64 = "ami-094307b97fdb69f51", linuxarm64 = "ami-0a7838ac807cc2fe0", windows = "ami-0810a5d723ee2eb02", ubuntu2404amd64 = "ami-071d6f1ccd645ba5c", ubuntu2404arm64 = "ami-09c358a9bc27d846c" }
    ap-south-1                   = { linuxamd64 = "ami-08f7471475d1c9139", linuxarm64 = "ami-08945656dd60c249e", windows = "ami-0c33f31af7cd2a301", ubuntu2404amd64 = "ami-0f743dbc504f71509", ubuntu2404arm64 = "ami-0bc36cb4a392b1292" }
    ap-northeast-2               = { linuxamd64 = "ami-04a99e1455bb4d7f8", linuxarm64 = "ami-08c64e2d758c35339", windows = "ami-0adefbbd5e4c77ca8", ubuntu2404amd64 = "ami-06b046dca7b50cc45", ubuntu2404arm64 = "ami-0ffd1f975fca06e9c" }
    ap-northeast-1               = { linuxamd64 = "ami-09761fd29ccc0b04f", linuxarm64 = "ami-06a970db01abb0edc", windows = "ami-0c4edf972ee2ca539", ubuntu2404amd64 = "ami-033940faf92ab7bb4", ubuntu2404arm64 = "ami-0d91e4047ed83537e" }
    ap-southeast-2               = { linuxamd64 = "ami-0c8b54c9959773308", linuxarm64 = "ami-0a175e94e3d59ee66", windows = "ami-0b7e759594da72d93", ubuntu2404amd64 = "ami-0232e0a199ead7f1a", ubuntu2404arm64 = "ami-05259a9f08b176d33" }
    ap-southeast-1               = { linuxamd64 = "ami-0aea4b0689b1d7933", linuxarm64 = "ami-0ce52425ee3af276d", windows = "ami-0f88b50017ebf6932", ubuntu2404amd64 = "ami-03baf1ccd38600999", ubuntu2404arm64 = "ami-00dc9ccc6eb8edf4a" }
    ca-central-1                 = { linuxamd64 = "ami-068944584f647614e", linuxarm64 = "ami-05b80b33a93605bd5", windows = "ami-0e12d49287ef665a3", ubuntu2404amd64 = "ami-0f04022cf344a967f", ubuntu2404arm64 = "ami-080478f318b03b245" }
    eu-central-1                 = { linuxamd64 = "ami-00a888bb09b8cf872", linuxarm64 = "ami-06db8ca5b9955304c", windows = "ami-06b07a2967b940e82", ubuntu2404amd64 = "ami-0ab5b232ec215832f", ubuntu2404arm64 = "ami-03510ec317bd4d323" }
    eu-west-1                    = { linuxamd64 = "ami-02bd760d489ff06c9", linuxarm64 = "ami-0fb506c06dd3b4648", windows = "ami-01b8982f07d33ca24", ubuntu2404amd64 = "ami-0bd08a575440f2a62", ubuntu2404arm64 = "ami-041397f0277de2254" }
    eu-west-2                    = { linuxamd64 = "ami-012b320e3c973b040", linuxarm64 = "ami-08904b968c7dedc26", windows = "ami-0526ba5a1e407595d", ubuntu2404amd64 = "ami-0083ede79e83b3715", ubuntu2404arm64 = "ami-06f6a10ddc06dc8b8" }
    eu-south-1                   = { linuxamd64 = "ami-060dc1bd84d8f3e9a", linuxarm64 = "ami-0749e931c81ef6721", windows = "ami-0843feb9715da66f8", ubuntu2404amd64 = "ami-0ba3caf31cad4001b", ubuntu2404arm64 = "ami-00374c42b4216d4e8" }
    eu-west-3                    = { linuxamd64 = "ami-0008a4ccfaf5bed38", linuxarm64 = "ami-0424bcaf06c0075da", windows = "ami-0ad03f15973808499", ubuntu2404amd64 = "ami-0ec661b6008055091", ubuntu2404arm64 = "ami-0bac9ef8a82f82794" }
    eu-north-1                   = { linuxamd64 = "ami-0d35bf1e212868221", linuxarm64 = "ami-0850bf6340e387aca", windows = "ami-07f69bbe38f410b3f", ubuntu2404amd64 = "ami-05e6fd0637289980e", ubuntu2404arm64 = "ami-010b25aabae42ce37" }
    sa-east-1                    = { linuxamd64 = "ami-0d9a201acfa8ae95b", linuxarm64 = "ami-090775a630fb2852c", windows = "ami-00d08c7ef1fb4a554", ubuntu2404amd64 = "ami-00259370e6391ed7a", ubuntu2404arm64 = "ami-0c31dd482cce914be" }
    cloudformation_stack_version = "v6.71.9"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix.
  # Both can be overridden to point at a self-built scaler binary.
  agent_scaler_s3_bucket         = var.agent_scaler_s3_bucket_override != "" ? var.agent_scaler_s3_bucket_override : (data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}")
  buildkite_agent_scaler_version = var.buildkite_agent_scaler_version_override != "" ? var.buildkite_agent_scaler_version_override : "1.14.0"
  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM (AWS Graviton) families carry a "g" in the options position, right after
  # the generation digit (e.g. c8gd, m8gn, r8gb, x8g, i8g, hpc7g, g5g, x2gd). a1
  # is the original Graviton1 family and predates this convention, so it has no "g".
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_arm_instance = (
    local.instance_type_family == "a1" ||
    can(regex("^[a-z]+[0-9]+g", local.instance_type_family))
  )

  # Burstable (T series) instances earn and spend CPU credits. The "t" series
  # letter in the first position identifies them (t2, t3, t3a, t4g).
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_burstable_instance = can(regex("^t[0-9]", local.instance_type_family))

  is_windows = var.instance_operating_system == "windows"
  is_ubuntu  = !local.is_windows && var.linux_distribution == "ubuntu2404"
  ami_architecture = local.is_windows ? "windows" : (
    local.is_ubuntu ? (local.is_arm_instance ? "ubuntu2404arm64" : "ubuntu2404amd64") : (local.is_arm_instance ? "linuxarm64" : "linuxamd64")
  )
  selected_ami_id = local.buildkite_ami_mapping[data.aws_region.current.region][local.ami_architecture]

  # Instance naming and timeout settings
  use_default_timeout      = var.instance_creation_timeout == ""
  use_custom_name          = var.instance_name != ""
  has_variable_size        = var.max_size != var.min_size
  enable_scheduled_scaling = var.enable_scheduled_scaling

  # EBS volume type detection and device naming
  use_default_volume_name = var.root_volume_name == ""
  is_gp3_volume           = var.root_volume_type == "gp3"
  supports_iops           = contains(["io1", "io2", "gp3"], var.root_volume_type)

  # Container registry access settings
  enable_ecr             = var.ecr_access_policy != "none"
  enable_ecr_pullthrough = contains(["readonly-pullthrough", "poweruser-pullthrough"], var.ecr_access_policy)

  # Buildkite agent token and parameter store settings
  use_custom_token_path    = var.buildkite_agent_token_parameter_store_path != ""
  use_custom_token_kms     = var.buildkite_agent_token_parameter_store_kms_key != ""
  create_token_parameter   = var.buildkite_agent_token_parameter_store_path == ""
  enable_graceful_shutdown = var.buildkite_agent_enable_graceful_shutdown

  # KMS key settings for pipeline signature verification
  use_existing_signing_key = var.pipeline_signing_kms_key_id != ""
  create_signing_key       = var.pipeline_signing_kms_key_id == "" && var.pipeline_signing_kms_key_spec != "none"
  has_signing_key          = local.create_signing_key || local.use_existing_signing_key
  signing_key_full_access  = var.pipeline_signing_kms_access == "sign-and-verify"
  signing_key_is_arn       = startswith(var.pipeline_signing_kms_key_id, "arn:")

  # Computed signing key ARN (for use in templates)
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_kms_key_id

  # Computed agent token parameter ARN (for IAM policies)
  agent_token_parameter_arn = local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter${var.buildkite_agent_token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"

  # Determine AMI ID from custom, parameter, or Buildkite mapping
  computed_ami_id = local.use_custom_ami ? var.image_id : (local.use_ami_parameter ? data.aws_ssm_parameter.ami[0].value : local.selected_ami_id)

  # Windows and Ubuntu AMIs root on /dev/sda1; Amazon Linux roots on /dev/xvda.
  root_device_name = local.use_default_volume_name ? (local.is_windows || local.is_ubuntu ? "/dev/sda1" : "/dev/xvda") : var.root_volume_name

  # SSH key and authorized users settings
  use_ssh_key        = var.key_name != ""
  enable_ssh_ingress = local.create_security_group && (local.use_ssh_key || var.authorized_users_url != "")

  # Cost allocation tag settings
  enable_cost_tags = var.enable_cost_allocation_tags

  # Stack naming and tagging
  stack_name_full = "${var.stack_name}-${random_id.stack_suffix.hex}"

  # aws_iam_role.name_prefix must be <= 38 chars because the AWS provider appends
  # a generated suffix and IAM role names must be <= 64 chars.
  stop_buildkite_agents_role_name_prefix = substr("${local.stack_name_full}-stop-bk-", 0, 38)

  common_tags = merge(
    var.tags,
    local.enable_cost_tags ? {
      (var.cost_allocation_tag_name) = var.cost_allocation_tag_value
    } : {},
    {
      ManagedBy = "Terraform"
      Stack     = local.stack_name_full
    }
  )
}
