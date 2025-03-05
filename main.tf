terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}


locals {
  key_name = "harness_terraform"
  private_key_path = "/path/to/your/key/your-key.pem"
  file_destination =  "/tmp/your-key.pem"
  chmod_command = "chmod 400 '/tmp/your-key.pem'"
}


provider "aws" {
  region = "us-west-1"
}

resource "aws_vpc" "main_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main_vpc"
  }
}

resource "aws_internet_gateway" "harness-igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "harness-igw"
  }
}

resource "aws_subnet" "harness-public-subnet-1b" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1b"

  tags = {
    Name = "harness-public-subnet-1b"
  }
}


resource "aws_route_table" "harness-public-rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.harness-igw.id
  }

  tags = {
    Name = "harness-public-rt"
  }
}

resource "aws_route_table_association" "devops-associate-public-subnets-1b" {
  subnet_id      = aws_subnet.harness-public-subnet-1b.id
  route_table_id = aws_route_table.harness-public-rt.id
}

resource "aws_security_group" "harness-public-subnet-sg" {
  name        = "harness-public-subnet-sg"
  description = "Allow SSH inboud traffic and all outbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  tags = {
    Name = "harness-public-subnet-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.harness-public-subnet-sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 22
  ip_protocol = "tcp"
  to_port = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.harness-public-subnet-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_instance" "harness" {
  ami           = "ami-08d4f6bbae664bd41"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  availability_zone = "us-west-1b"
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.harness-public-subnet-sg.id]
  subnet_id = aws_subnet.harness-public-subnet-1b.id

    /*
  provisioner "file" {
    source = local.private_key_path
    destination = local.file_destination

    connection {
      host = self.public_ip
      private_key = file(local.private_key_path)
      user = "ec2-user"
      type = "ssh"
      timeout = "2m"
    }
  }

  provisioner "remote-exec" {
    inline = [ 
      "echo 'Configuring key pair'",
      local.chmod_command
     ]
    connection {
      host = self.public_ip
      private_key = file(local.private_key_path)
      user = "ec2-user"
      type = "ssh"
      timeout = "2m"
    }
  }
  */

  tags = {
    Name = "harness_instance"
  }
}