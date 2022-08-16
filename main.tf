## AWS SSH Keypair
resource "aws_key_pair" "nextcloud_ssh_key" {
  key_name   = "nextcloud_ssh_key"
  public_key = file(var.aws_ssh_public_key)
}

## AWS VPC
resource "aws_vpc" "aws_vpc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = false
  tags                 = { Name = "aws_vpc" }
}

## AWS Internet Gateway
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

## Nextcloud01 Instance
resource "aws_instance" "nextcloud01" {
  tags                        = { Name = "nextcloud01" }
  key_name                    = aws_key_pair.nextcloud_ssh_key.key_name
  ami                         = var.aws_ami[var.aws_region]
  availability_zone           = var.aws_az
  instance_type               = var.aws_instance_size
  user_data                   = file(var.aws_instance_user_data)
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
    volume_size           = var.aws_instance_disk_size
  }

}

## AWS Nextcloud Security Group
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

## AWS IAM User with S3 bucket and KMS access
resource "aws_iam_user" "nextcloud-s3-user" {
  name = var.aws_iam_bucket_user
}

## AWS IAM User Access Credentials
resource "aws_iam_access_key" "nextcloud-s3-user" {
  user = aws_iam_user.nextcloud-s3-user.name
}

data "aws_canonical_user_id" "nextcloud-s3-user" {}
data "aws_caller_identity" "current" {}

## AWS KMS Key
resource "aws_kms_key" "nextcloud_bucket_key" {
  description             = "This key is used to encrypt Nextcloud bucket objects"
  deletion_window_in_days = 10
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  policy                  = <<EOF
{
  "Version": "2012-10-17",
  "Id": "kms-key-policy",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${aws_iam_user.nextcloud-s3-user.arn}",
          "${data.aws_caller_identity.current.arn}"
        ]},
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_s3_account_public_access_block" "public_access_block" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

## AWS S3 Bucket
resource "aws_s3_bucket" "nextcloud_bucket" {
  bucket = var.aws_bucket_name
  force_destroy = true
  depends_on    = [aws_iam_user.nextcloud-s3-user]
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = var.aws_bucket_name
  access_control_policy {
    grant {
      grantee {
        id   = data.aws_canonical_user_id.nextcloud-s3-user.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }
    owner {
      id = data.aws_canonical_user_id.nextcloud-s3-user.id
    }
  }
}
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = var.aws_bucket_name
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "server_side_encryption_config" {
  bucket = var.aws_bucket_name

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.nextcloud_bucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

## AWS KMS Policy
resource "aws_iam_policy" "kms_policy" {
  name        = "kms_policy"
  path        = "/"
  description = "IAM Policy to allow use of KMS Key"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
      "Effect": "Allow",
      "Action": [
        "kms:Describe*",
        "kms:List*",
        "kms:Get*",
        "kms:Encrypt",
        "kms:Decrypt"
        ],
      "Resource": "*"
    }
}
EOF
}

## AWS S3 Bucket Policy
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
                "arn:aws:s3:::${var.aws_bucket_name}",
                "arn:aws:s3:::${var.aws_bucket_name}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "s3_policy_attach" {
  user       = aws_iam_user.nextcloud-s3-user.name
  policy_arn = aws_iam_policy.nextcloud_s3_policy.arn
}

resource "aws_iam_user_policy_attachment" "kms_policy_attach" {
  user       = aws_iam_user.nextcloud-s3-user.name
  policy_arn = aws_iam_policy.kms_policy.arn
}
