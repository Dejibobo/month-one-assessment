terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region  # you can change this later
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "techcorp-vpc"
  }
}
# Get available AZs in your region
data "aws_availability_zones" "available" {
  state = "available"
}

# Public subnets
resource "aws_subnet" "public" {
  for_each = {
    a = { cidr = "10.0.1.0/24", az_index = 0 }
    b = { cidr = "10.0.2.0/24", az_index = 1 }
  }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = data.aws_availability_zones.available.names[each.value.az_index]
  map_public_ip_on_launch = true

  tags = {
    Name = "techcorp-public-subnet-${each.key}"
    Tier = "public"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = {
    a = { cidr = "10.0.3.0/24", az_index = 0 }
    b = { cidr = "10.0.4.0/24", az_index = 1 }
  }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = data.aws_availability_zones.available.names[each.value.az_index]

  tags = {
    Name = "techcorp-private-subnet-${each.key}"
    Tier = "private"
  }
}
# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "techcorp-igw"
  }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "techcorp-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "techcorp-nat-eip"
  }
}

# NAT Gateway in one of the public subnets
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id

  tags = {
    Name = "techcorp-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "techcorp-private-rt"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
# Bastion Security Group
resource "aws_security_group" "bastion" {
  name        = "techcorp-bastion-sg"
  description = "Allow SSH from admin IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["105.112.216.234/32"] # replace with your own IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-bastion-sg"
  }
}

# Web Security Group
resource "aws_security_group" "web" {
  name        = "techcorp-web-sg"
  description = "Allow HTTP/HTTPS from internet, SSH from bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-web-sg"
  }
}

# Database Security Group
resource "aws_security_group" "db" {
  name        = "techcorp-db-sg"
  description = "Allow MySQL from web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from web SG"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techcorp-db-sg"
  }
}
# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
# Bastion Host
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id   # keep x86 AMI if using t3.micro
  instance_type = var.instance_type                     # Free Tier eligible
  subnet_id     = aws_subnet.public["a"].id
  key_name      = "terraform-key" 
  security_groups = [aws_security_group.bastion.id]

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# Web Servers
resource "aws_instance" "web" {
  for_each = {
    a = aws_subnet.private["a"].id
    b = aws_subnet.private["b"].id
  }

  ami           = data.aws_ami.amazon_linux.id   # keep x86 AMI if using t3.micro
  instance_type = "t3.micro"                     # Free Tier eligible
  subnet_id     = each.value
  security_groups = [aws_security_group.web.id]

  key_name      = "terraform-key"

# Startup script to install Apache and serve a page

  user_data = file("${path.module}/user_data/web_server_setup.sh")

  tags = {
    Name = "techcorp-web-${each.key}"
  }
}

# Database Server
resource "aws_instance" "db" {
  ami           = data.aws_ami.amazon_linux.id   # keep x86 AMI if using t3.micro
  instance_type = "t3.micro"                     # Free Tier eligible
  subnet_id     = aws_subnet.private["a"].id
  security_groups = [aws_security_group.db.id]

  key_name      = "terraform-key"

user_data = file("${path.module}/user_data/db_server_setup.sh")

  tags = {
    Name = "techcorp-db"
  }
}
# Create ALB
resource "aws_lb" "app" {
  name               = "techcorp-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name = "techcorp-alb"
  }
}

# Target group for web servers
resource "aws_lb_target_group" "web_tg" {
  name     = "techcorp-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = "80"
  }

  tags = {
    Name = "techcorp-web-tg"
  }
}

# Register web servers with target group
resource "aws_lb_target_group_attachment" "web" {
  for_each = aws_instance.web
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = each.value.id
  port             = 80
}

# Listener for ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}
