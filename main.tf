#variables
variable "region" {
  description = "region name"
}

variable "authentication_profile" {
  description = "authentication profile"
}

variable "subnet_prefix" {
  description = "cidr block for the subnet"
}

variable "ec2_instance_key" {
  description = "key for ec2 instance"
}

variable "ec2_instance_ami" {
  description = "ami for the ec2 instances"
}

variable "ec2_instance_type" {
  description = "instance type for the ec2 instances"
}

variable "ec2_availability" {
  description = "ec2 availability region"
}


# aws provider
provider "aws" {
  region                  = var.region
  profile                 = var.authentication_profile
}

#1.create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "prod"
  }
}

#2.create a internet gateway
resource "aws_internet_gateway" "prod-ig" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod"
  }
}

#3.create a custom route table
resource "aws_route_table" "prod-rt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
      #default: allow all
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-ig.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-ig.id
  }

  tags = {
    Name = "prod"
  }
}

#4.create a subnet
resource "aws_subnet" "prod-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = var.ec2_availability

  tags = {
    Name = var.subnet_prefix[0].name
  }
}

#5.Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.prod-subnet.id
  route_table_id = aws_route_table.prod-rt.id
}

#6.create security group to allow port 22,80,443
resource "aws_security_group" "prod-sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#7.create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.prod-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.prod-sg.id]

}

#8.Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.prod-ig]
}

#9.create ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami               = var.ec2_instance_ami
  instance_type     = var.ec2_instance_type
  availability_zone = var.ec2_availability
  key_name          = var.ec2_instance_key

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo My very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
}