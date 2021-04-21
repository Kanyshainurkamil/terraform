provider "aws" {
   region = "us-east-2"
}

#resource "provider_resourcename" "name" }

# 1. Create vpc 

resource "aws_vpc" "firsttf-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "firsttf-vpc"
  }
}

# 2. Create Internet Gateway 

resource "aws_internet_gateway" "firsttf-ig" {
  vpc_id = aws_vpc.firsttf-vpc.id

  tags = {
    Name = "firsttf-ig"
  }
}

# 3. Create Custom Route Table

resource "aws_route_table" "tf-routetable" {
  vpc_id = aws_vpc.firsttf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.firsttf-ig.id
  }

  route {
    ipv6_cidr_block    = "::/0"
    gateway_id         = aws_internet_gateway.firsttf-ig.id
  }

  tags = {
    Name = "tf-routetable"
  }
}

# 4. Create a Subnet

resource "aws_subnet" "tf-subnet" {
  vpc_id     = aws_vpc.firsttf-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone= "us-east-2a"

  tags = {
    Name = "tf-subnet"
  }
}
# 5. Associate subnet with Route Table 

resource "aws_route_table_association" "terraform-rtable" {
  subnet_id      = aws_subnet.tf-subnet.id
  route_table_id = aws_route_table.tf-routetable.id
}

# 6. Create Security Group to allow port 22,80,443

resource "aws_security_group" "terraform-SG" {
  name        = "allow_web-traffif"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.firsttf-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
    ingress {
    description = "HTTP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
    ingress {
    description = "SSH"
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

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "terraform-webserver" {
  subnet_id       = aws_subnet.tf-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.terraform-SG.id]

}
# 8. Assign an Elastic IP to the newtork interface craeted in step 7 

resource "aws_eip" "one" {
  vpc                        = true
  network_interface          = aws_network_interface.terraform-webserver.id
  associate_with_private_ip  = "10.0.1.50"
  depends_on                 = [aws_internet_gateway.firsttf-ig]
}

# 9. Create Linux Server and install/enable httpd

resource "aws_instance" "terraform-instance" {
  ami                  = "ami-09558250a3419e7d0"
  instance_type        = "t2.micro"
  availability_zone    = "us-east-2a"

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.terraform-webserver.id 
  } 

  user_data = <<-EOF
                #! /bin/bash
                sudo yum update -y
                sudo yum install httpd -y
                sudo systemctl start httpd
                sudo bash -c 'echo POWER OF TERRAFORM > /var/www/html/index.html'
                EOF
  tags = {
    Name = "terraform-userdata"
  }
} 
