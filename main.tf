provider "aws" {
  region = "us-east-1" # Change this to your preferred AWS region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MainVPC"
  }
}

# Public Subnet 1
resource "aws_subnet" "public-AZ1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Change to your preferred AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-AZ1"
  }
}

# Public Subnet 2
resource "aws_subnet" "public-AZ2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b" # Change to your preferred AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-AZ2"
  }
}

# Internet Gateway for Public Access
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_AZ1" {
  subnet_id      = aws_subnet.public-AZ1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_AZ2" {
  subnet_id      = aws_subnet.public-AZ2.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for ALB
resource "aws_security_group" "proxy_sg" {
  vpc_id = aws_vpc.main.id

  # Allow inbound HTTP (Port 80) from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB-SG"
  }
}

# Create the Application Load Balancer (ALB)
resource "aws_lb" "proxy" {
  name               = "proxy"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.proxy_sg.id]
  subnets            = [aws_subnet.public-AZ1.id, aws_subnet.public-AZ2.id]

  enable_deletion_protection = false

  tags = {
    Name = "proxy"
  }
}

# Target Group for the ALB
resource "aws_lb_target_group" "proxy_tg" {
  name     = "proxy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "proxy-tg"
  }
}

# Register an EC2 Instance with the Target Group
resource "aws_instance" "proxy" {
  ami           = "ami-0c55b159cbfafe1f0"  # Change this to your desired AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public-AZ1.id
  security_groups = [aws_security_group.proxy_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "<h1>Hello from EC2 behind ALB</h1>" > /var/www/html/index.html
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name = "Proxy-Instance"
  }
}

# Attach the EC2 Instance to the Target Group
resource "aws_lb_target_group_attachment" "proxy_attachment" {
  target_group_arn = aws_lb_target_group.proxy_tg.arn
  target_id        = aws_instance.proxy.id
  port            = 80
}

# ALB Listener to Forward Traffic
resource "aws_lb_listener" "proxy_listener" {
  load_balancer_arn = aws_lb.proxy.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy_tg.arn
  }
}
