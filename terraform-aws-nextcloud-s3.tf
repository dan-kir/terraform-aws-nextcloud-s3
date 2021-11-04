## Environment Variables - terraform-aws-ec2-instance.auto.tfvars
variable "aws_region" {}
variable "aws_az" {}
variable "aws_ami" { type = map(string) }
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_ssh_public_key" {}
variable "aws_ssh_private_key" {}
variable "aws_instance_size" {}
variable "aws_vpc_cidr" {}
variable "aws_net_cidr" {}
variable "aws_nextcloud01_private_ip" {}

## AWS Provider Configuration
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

## AWS SSH Keypair
resource "aws_key_pair" "nextcloud_ssh_key" {
  key_name   = "nextcloud_ssh_key"
  public_key = file(var.aws_ssh_public_key)
}

## Define AWS VPC
resource "aws_vpc" "aws_vpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = false
  tags                 = { Name = "aws_vpc" }
}

## Internet Gateway
resource "aws_internet_gateway" "aws_gateway" {
  vpc_id = aws_vpc.aws_vpc.id
  tags   = { Name = "aws_gateway" }
}

## Nextcloud Subnet
resource "aws_subnet" "aws_net" {
  vpc_id            = aws_vpc.aws_vpc.id
  cidr_block        = var.aws_net_cidr
  availability_zone = var.aws_az
  tags              = { Name = "aws_net" }
}

## Route Table
resource "aws_route_table" "public_routes" {
  vpc_id = aws_vpc.aws_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_gateway.id
  }
  tags = { Name = "public_routes" }
}

## Assign route table to aws_net
resource "aws_route_table_association" "aws_net_routes" {
  subnet_id      = aws_subnet.aws_net.id
  route_table_id = aws_route_table.public_routes.id
}

## Nextcloud01 Elastic IP
resource "aws_eip" "nextcloud01_eip" {
  vpc      = true
  instance = aws_instance.nextcloud01.id
}

## Nextcloud Instance
resource "aws_instance" "nextcloud01" {
  tags                        = { Name = "nextcloud01" }
  key_name                    = aws_key_pair.nextcloud_ssh_key.key_name
  ami                         = var.aws_ami[var.aws_region]
  availability_zone           = var.aws_az
  instance_type               = var.aws_instance_size
  user_data                   = file("scripts/nextcloud01_bootstrap.sh")
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.aws_net.id
  private_ip                  = var.aws_nextcloud01_private_ip
  source_dest_check           = true # disable if implementing NAT
  monitoring                  = true
  vpc_security_group_ids = [
    aws_security_group.nextcloud_sg.id
  ]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = 16
  }

}

resource "aws_security_group" "nextcloud_sg" {
  name        = "nextcloud_sg"
  description = "Nextcloud security group"
  vpc_id      = aws_vpc.aws_vpc.id
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
  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_iam_user" "nextcloud-s3" {
  name = "nextcloud-s3"
}

resource "aws_iam_access_key" "nextcloud-s3" {
  user = aws_iam_user.nextcloud-s3.name
}

data "aws_canonical_user_id" "nextcloud-s3" {}

## The bucket name here needs to be unique and match the name in the
## s3 policy below
resource "aws_s3_bucket" "nextcloud_bucket" {
  bucket        = "tf-nextcloud-bucket"
  #region        = var.aws_region
  force_destroy = true
  depends_on    = [aws_iam_user.nextcloud-s3]

  grant {
    id          = data.aws_canonical_user_id.nextcloud-s3.id
    type        = "CanonicalUser"
    permissions = ["FULL_CONTROL"]
  }

  #server_side_encryption_configuration {
  #  rule {
  #    apply_server_side_encryption_by_default {
  #      kms_master_key_id = aws_kms_key.bucket_key.arn
  #      sse_algorithm     = "aws:kms"
  #    }
  #  }
  #}
}

resource "aws_iam_policy" "nextcloud_s3_policy" {
  name        = "nextcloud_s3_policy"
  path        = "/"
  description = "S3 policy for Nextcloud IAM user"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:ListAllMyBuckets"
            ],
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::tf-nextcloud-bucket",
                "arn:aws:s3:::tf-nextcloud-bucket/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "s3_policy_attach" {
  user       = aws_iam_user.nextcloud-s3.name
  policy_arn = aws_iam_policy.nextcloud_s3_policy.arn
}

output "nextcloud-s3_secret" {
  value = aws_iam_access_key.nextcloud-s3.secret
  sensitive = true
}

output "nextcloud-s3_access_token" {
  value = aws_iam_access_key.nextcloud-s3.id
}

output "nextcloud01_eip" {
  value = aws_eip.nextcloud01_eip.public_ip
}
