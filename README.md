terraform-aws-nextcloud-s3
==============================
Template a VPC, Internet Gateway, Network, Security Groups, IAM user, S3 Bucket
and Instance with Elastic IP.

The S3 bucket can be configured as a storage back-end for Nextcloud.

The public IP address (Elastic IP) and IAM access token will be outputted at completion.

The IAM secret can be parsed from the Terraform state

Eg. `terraform state pull | jq '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes'`

*Working on templating S3 server-side encryption with an AWS Key Management Service (AWS KMS) key*

Requirements
------------
Requires Terraform 1.0.8 or later.

Terraform Variables
--------------
The following is configurable in `terraform-aws-ec2-instance.auto.tfvars`
* Region and Availability Zone
* AMI IDs
* Application Credentials
* SSH Keys
* Instance Size
* IP Addressing

License
-------
GPL-3.0 License

Author Information
------------------
This template was created by Dan Kir
