# ----- EC2 instance role (ECS agent registration, ECR read, SSM) -----
resource "aws_iam_role" "ecs_instance" {
  name = "agent-workshop-ecs-instance${local.name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.ecs_instance.name
  policy_arn = each.value
}

# Allow the instance to attach the stable Elastic IP to itself at boot
# (aws ec2 associate-address in the launch-template user_data). AssociateAddress
# does not support resource-level scoping, so the action is granted on "*".
resource "aws_iam_role_policy" "ecs_instance_eip" {
  name = "associate-eip"
  role = aws_iam_role.ecs_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:AssociateAddress"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "agent-workshop-ecs-instance${local.name_suffix}"
  role = aws_iam_role.ecs_instance.name
}

# ----- ECS task execution role (pull image from ECR, write to CloudWatch Logs) -----
resource "aws_iam_role" "ecs_task_execution" {
  name = "agent-workshop-ecs-task-execution${local.name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
