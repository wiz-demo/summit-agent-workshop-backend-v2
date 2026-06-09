# ECS-optimized Amazon Linux 2023 AMI (region-aware via the provider)
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# Stable public address for the demo host. The ASG instance is replaceable and
# its auto-assigned public IP changes on every replacement, which made Wiz age
# out the attack-surface endpoint and auto-resolve its findings. This EIP is
# allocated once per workspace and re-associated at boot (see launch template
# user_data) so Wiz always scans the same address and findings stay OPEN.
resource "aws_eip" "backend" {
  domain = "vpc"
  tags = {
    Name   = "agent-workshop-backend${local.name_suffix}"
    extend = "true"
  }
}

resource "aws_security_group" "backend" {
  name        = "agent-workshop-backend${local.name_suffix}"
  description = "Allow public access on 8000 to ECS container host"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "App port 8000 from anywhere (mirrors prior internet-facing ELB)"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress (ECR pull, CloudWatch Logs, SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "agent-workshop-backend${local.name_suffix}"
  }
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "agent-workshop${local.name_suffix}-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = "t3.large"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [aws_security_group.backend.id]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config

    # Re-associate the stable Elastic IP onto whichever instance the ASG just
    # launched, so the public address never changes across replacements. The
    # instance still has its auto-assigned public IP here (map_public_ip_on_launch),
    # giving outbound internet to reach the EC2 API before the EIP takes over.
    TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    command -v aws >/dev/null 2>&1 || dnf install -y awscli-2 || dnf install -y aws-cli
    aws ec2 associate-address --region ${var.region} --instance-id "$INSTANCE_ID" --allocation-id ${aws_eip.backend.allocation_id} --allow-reassociation
  EOT
  )

  # Tag the instance at creation time. The SCP on this account explicitly
  # denies ec2:RunInstances unless owner/extend are present on the instance.
  # ASG-level propagate_at_launch sets them too, but those are applied by the
  # ASG service AFTER instance creation — the SCP check is at RunInstances
  # time, so the launch template must carry them itself.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name   = "agent-workshop-backend${local.name_suffix}"
      owner  = var.owner
      extend = "true"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name   = "agent-workshop-backend${local.name_suffix}"
      owner  = var.owner
      extend = "true"
    }
  }
}

resource "aws_autoscaling_group" "ecs" {
  name_prefix      = "agent-workshop${local.name_suffix}-"
  desired_capacity = 1
  min_size         = 1
  max_size         = 1

  vpc_zone_identifier = [aws_subnet.public[0].id]

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  # Required for the ECS capacity provider to manage the ASG
  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  # Required project tags (per CLAUDE.md). default_tags on the provider does
  # NOT propagate to ASG-launched instances, so set them explicitly.
  tag {
    key                 = "owner"
    value               = var.owner
    propagate_at_launch = true
  }

  tag {
    key                 = "extend"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "agent-workshop-ec2${local.name_suffix}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 1
    }
  }
}
