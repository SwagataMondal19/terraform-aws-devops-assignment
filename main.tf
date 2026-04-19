provider "aws" {

  region = "ap-south-1"

}
 
# ---------------- VPC ----------------

resource "aws_vpc" "main" {

  cidr_block = "10.0.0.0/16"

}
 
# ---------------- PUBLIC SUBNETS ----------------

resource "aws_subnet" "public1" {

  vpc_id                  = aws_vpc.main.id

  cidr_block              = "10.0.1.0/24"

  availability_zone       = "ap-south-1a"

  map_public_ip_on_launch = true

}
 
resource "aws_subnet" "public2" {

  vpc_id                  = aws_vpc.main.id

  cidr_block              = "10.0.2.0/24"

  availability_zone       = "ap-south-1b"

  map_public_ip_on_launch = true

}
 
# ---------------- PRIVATE SUBNETS ----------------

resource "aws_subnet" "private1" {

  vpc_id            = aws_vpc.main.id

  cidr_block        = "10.0.3.0/24"

  availability_zone = "ap-south-1a"

}
 
resource "aws_subnet" "private2" {

  vpc_id            = aws_vpc.main.id

  cidr_block        = "10.0.4.0/24"

  availability_zone = "ap-south-1b"

}
 
# ---------------- IGW ----------------

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

}
 
# ---------------- PUBLIC ROUTE ----------------

resource "aws_route_table" "public_rt" {

  vpc_id = aws_vpc.main.id

}
 
resource "aws_route" "public_internet" {

  route_table_id         = aws_route_table.public_rt.id

  destination_cidr_block = "0.0.0.0/0"

  gateway_id             = aws_internet_gateway.igw.id

}
 
resource "aws_route_table_association" "public_assoc1" {

  subnet_id      = aws_subnet.public1.id

  route_table_id = aws_route_table.public_rt.id

}
 
resource "aws_route_table_association" "public_assoc2" {

  subnet_id      = aws_subnet.public2.id

  route_table_id = aws_route_table.public_rt.id

}
 
# ---------------- NAT ----------------

resource "aws_eip" "nat" {

  domain = "vpc"

}
 
resource "aws_nat_gateway" "nat" {

  subnet_id     = aws_subnet.public1.id

  allocation_id = aws_eip.nat.id

}
 
# ---------------- PRIVATE ROUTE ----------------

resource "aws_route_table" "private_rt" {

  vpc_id = aws_vpc.main.id

}
 
resource "aws_route" "private_nat" {

  route_table_id         = aws_route_table.private_rt.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id         = aws_nat_gateway.nat.id

}
 
resource "aws_route_table_association" "private_assoc1" {

  subnet_id      = aws_subnet.private1.id

  route_table_id = aws_route_table.private_rt.id

}
 
resource "aws_route_table_association" "private_assoc2" {

  subnet_id      = aws_subnet.private2.id

  route_table_id = aws_route_table.private_rt.id

}
 
# ---------------- SECURITY GROUPS ----------------

resource "aws_security_group" "alb_sg" {

  vpc_id = aws_vpc.main.id
 
  ingress {

    from_port = 80

    to_port   = 80

    protocol  = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }
 
  egress {

    from_port = 0

    to_port   = 0

    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

}
 
resource "aws_security_group" "app_sg" {

  vpc_id = aws_vpc.main.id
 
  ingress {

    from_port       = 80

    to_port         = 80

    protocol        = "tcp"

    security_groups = [aws_security_group.alb_sg.id]

  }
 
  egress {

    from_port = 0

    to_port   = 0

    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

}
 
# ---------------- IAM (SSM) ----------------

resource "aws_iam_role" "ssm_role" {

  name = "ssm-role"
 
  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [{

      Effect = "Allow"

      Principal = { Service = "ec2.amazonaws.com" }

      Action = "sts:AssumeRole"

    }]

  })

}
 
resource "aws_iam_role_policy_attachment" "ssm_attach" {

  role       = aws_iam_role.ssm_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}
 
resource "aws_iam_instance_profile" "ssm_profile" {

  role = aws_iam_role.ssm_role.name

}
 
# ---------------- LAUNCH TEMPLATE ----------------

resource "aws_launch_template" "lt" {

  name_prefix   = "neodash-lt"

  image_id      = var.ami_id

  instance_type = "t3.micro"
 
  vpc_security_group_ids = [aws_security_group.app_sg.id]
 
  iam_instance_profile {

    name = aws_iam_instance_profile.ssm_profile.name

  }
 
  user_data = base64encode(<<EOF

#!/bin/bash

yum install -y httpd

systemctl start httpd

systemctl enable httpd

echo "Hello from ASG" > /var/www/html/index.html

EOF

  )

}
 
# ---------------- ALB ----------------

resource "aws_lb" "alb" {

  load_balancer_type = "application"

  subnets            = [

    aws_subnet.public1.id,

    aws_subnet.public2.id

  ]

  security_groups    = [aws_security_group.alb_sg.id]

}
 
resource "aws_lb_target_group" "tg" {

  port     = 80

  protocol = "HTTP"

  vpc_id   = aws_vpc.main.id
 
  health_check {

    path = "/"

  }

}
 
resource "aws_lb_listener" "listener" {

  load_balancer_arn = aws_lb.alb.arn

  port              = 80
 
  default_action {

    type             = "forward"

    target_group_arn = aws_lb_target_group.tg.arn

  }

}
 
# ---------------- ASG ----------------

resource "aws_autoscaling_group" "asg" {

  min_size            = 1

  max_size            = 2

  desired_capacity    = 1

  vpc_zone_identifier = [

    aws_subnet.private1.id,

    aws_subnet.private2.id

  ]
 
  launch_template {

    id      = aws_launch_template.lt.id

    version = "$Latest"

  }
 
  target_group_arns = [aws_lb_target_group.tg.arn]

}
 
