#aws provider variables
region="us-east-2"
authentication_profile="default"

#subnet variables
subnet_prefix = [{ cidr_block = "10.0.1.0/24", name = "prod_subnet" }, { cidr_block = "10.0.2.0/24", name = "dev_subnet" }]

#variables for ec2 instances
ec2_instance_key="main-key"
ec2_instance_ami="ami-0a91cd140a1fc148a"
ec2_instance_type="t2.micro"
ec2_availability="us-east-2a"