provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

    tags = {
        Name = "main"
    }
}

resource "aws_subnet" "public-AZ1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
    tags = {
        Name = "public-AZ1"
    }
}

resource "aws_subnet" "private-AZ1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

    tags = {
        Name = "private-AZ1"
    }
}

resource "aws_subnet" "public-AZ2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
    tags = {
        Name = "public-AZ2"
    }
}

resource "aws_subnet" "private-AZ2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

    tags = {
        Name = "private-AZ2"
    }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.main.id
    tags = {
        Name = "IGW"
    }  
}

resource "aws_route_table" "public-routes" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  
  tags = {
    Name = "Public-Routes"
  }
}

resource "aws_route_table_association" "public-AZ1" {
  subnet_id      = aws_subnet.public-AZ1.id
  route_table_id = aws_route_table.public-routes.id
}

resource "aws_route_table_association" "public-AZ2" {
  subnet_id      = aws_subnet.public-AZ2.id
  route_table_id = aws_route_table.public-routes.id
}

resource "aws_eip" "NAT-EIP" {
  domain = "vpc"
}

resource "aws_nat_gateway" "NAT-GW" {
  allocation_id = aws_eip.NAT-EIP.id
  subnet_id = aws_subnet.public-AZ1.id

  tags = {
    Name = "NAT-GW"
  }

  depends_on = [aws_internet_gateway.IGW]
}

resource "aws_route_table" "private-routes" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT-GW.id
  }

  tags = {
    Name = "Private-Routes"
  }
}

resource "aws_route_table_association" "private-AZ1" {
  subnet_id      = aws_subnet.private-AZ1.id
  route_table_id = aws_route_table.private-routes.id
}

resource "aws_route_table_association" "private-AZ2" {
  subnet_id      = aws_subnet.private-AZ2.id
  route_table_id = aws_route_table.private-routes.id
}

resource "aws_security_group" "proxy_sg" {
  name        = "proxy_sg"
  description = "Allow inbound traffic"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_sg" {
  name        = "backend_sg"
  description = "Allow inbound traffic"
  vpc_id = aws_vpc.main.id

ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "proxy1_key" {
  key_name   = "proxy_key"
  public_key = file("./proxyKey.pub")
}

resource "aws_instance" "proxy1" {
  ami           = "ami-05b10e08d247fb927"
  instance_type = "t3.micro"
  key_name = aws_key_pair.proxy1_key.key_name
  subnet_id     = aws_subnet.public-AZ1.id
  vpc_security_group_ids = [aws_security_group.proxy_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "proxy1"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras enable nginx1 -y
    sudo yum install -y nginx

    # Create Nginx configuration in the correct directory
    sudo tee /etc/nginx/conf.d/reverse-proxy.conf <<PROXY_CFG
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://${aws_lb.backend.dns_name};
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    PROXY_CFG

    # Restart Nginx to apply changes
    sudo systemctl restart nginx
    sudo systemctl enable nginx
  EOF
} 

resource "aws_instance" "proxy2" {
  ami           = "ami-05b10e08d247fb927"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public-AZ2.id
  vpc_security_group_ids = [aws_security_group.proxy_sg.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.proxy1_key.key_name
  tags = {
    Name = "proxy2"
  }
  
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras enable nginx1 -y
    sudo yum install -y nginx

    # Create Nginx configuration in the correct directory
    sudo tee /etc/nginx/conf.d/reverse-proxy.conf <<PROXY_CFG
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://${aws_lb.backend.dns_name};
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    PROXY_CFG

    # Restart Nginx to apply changes
    sudo systemctl restart nginx
    sudo systemctl enable nginx
  EOF
}

resource "aws_lb_target_group" "proxy_tg" {
  name     = "proxy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "proxy1_attach" {
  target_group_arn = aws_lb_target_group.proxy_tg.arn
  target_id        = aws_instance.proxy1.id
  port            = 80
  depends_on      = [aws_instance.proxy1]
}

resource "aws_lb_target_group_attachment" "proxy2_attach" {
  target_group_arn = aws_lb_target_group.proxy_tg.arn
  target_id        = aws_instance.proxy2.id
  port            = 80
  depends_on      = [aws_instance.proxy2]
}

resource "aws_lb_listener" "proxy_listener" {
  load_balancer_arn = aws_lb.proxy.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy_tg.arn
  }
}

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

resource "aws_key_pair" "backend_key1" {
 key_name = "backend_key"
 public_key = file("./backendKey.pub")
}

resource "aws_instance" "backend1" {
  ami           = "ami-05b10e08d247fb927"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private-AZ1.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id, aws_security_group.proxy_sg.id]
  key_name = aws_key_pair.backend_key1.key_name
  tags = {
    Name = "backend1"
  }

  user_data = <<-EOF
                #!/bin/bash
                amazon-linux-extras enable nginx1
                yum install -y nginx
                echo "backend 1 test test test" > /usr/share/nginx/html/index.html
                systemctl start nginx
                systemctl enable nginx
              EOF

}

resource "aws_instance" "backend2" {
  ami           = "ami-05b10e08d247fb927"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private-AZ2.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id, aws_security_group.proxy_sg.id]
  key_name = aws_key_pair.backend_key1.key_name
  tags = {
    Name = "backend2"
  }

  user_data = <<-EOF
                #!/bin/bash
                amazon-linux-extras enable nginx1
                yum install -y nginx
                echo "backend 2 test test test" > /usr/share/nginx/html/index.html
                systemctl start nginx
                systemctl enable nginx
              EOF
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "backend1_attach" {
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend1.id
  port            = 80
  depends_on      = [aws_instance.backend1]
}

resource "aws_lb_target_group_attachment" "backend2_attach" {
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend2.id
  port            = 80
  depends_on      = [aws_instance.backend2]
}

resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

resource "aws_lb" "backend" {
  name               = "backend"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_sg.id, aws_security_group.proxy_sg.id]
  subnets            = [aws_subnet.private-AZ1.id, aws_subnet.private-AZ2.id]

  enable_deletion_protection = false

  tags = {
    Name = "backend"
  }
}

 output "proxy_dns" {
  value = aws_lb.proxy.dns_name
 }