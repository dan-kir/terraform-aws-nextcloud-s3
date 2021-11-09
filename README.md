terraform-aws-nextcloud-s3
==============================
This template includes the following:
* Virtual Private Cloud (VPC)
* Internet Gateway
* Subnet
* Route Table
* Security Group
* IAM user
* IAM Access Credentials
* KMS Key
* S3 Bucket
* EC2 Instance
* Elastic IP (EIP)

The S3 bucket is configure with server-side encryption by default using a KMS key.

The EIP and IAM user access token will be outputted at completion.

The IAM user access secret can be parsed from the Terraform state.

Eg. `terraform state pull | jq '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes'`


Requirements
------------
Requires Terraform 1.0.8 or later.

Variables
--------------
The following is defined in - `terraform-aws-ec2-instance.auto.tfvars`
* Region and Availability Zone
* AMI IDs
* Application Credentials
* SSH Keys
* Instance Size
* Instance Disk Size
* IP Addressing
* S3 Bucket Name
* S3 Bucket User

License
-------
GPL-3.0 License

Author Information
------------------
This template was created by Dan Kir
