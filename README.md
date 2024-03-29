terraform-aws-nextcloud-s3
==============================
[![Actively Maintained](https://img.shields.io/badge/Maintenance%20Level-Actively%20Maintained-green.svg)](https://gist.github.com/cheerfulstoic/d107229326a01ff0f333a1d3476e068d)

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
The following is configurable in - `variables.tfvars`
* Region and Availability Zone
* AMI IDs
* Application Credentials
* SSH Keys
* Instance Size
* Instance Disk Size
* IP Addressing
* S3 Bucket Name
* S3 Bucket User

Graph
-------------
![alt text](graph.svg "graph.svg")

License
-------
GPL-3.0 License

Author Information
------------------
This template was created by Dan Kir
