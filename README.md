# Terraform-Project


![Architecture Diagram Image](https://github.com/user-attachments/assets/8676fd4d-94b8-4c13-b95f-4dfe3295afce)


# Getting Started
- First Clone repository ```git clone <repo-url>```
- Then which type of solution for private instance you preferred [Using NAT Gateway, Using VPC endpoint]
- if ``` NAT Gateway ```
    - Create new Terraform workspace ``` terraform workspace new <NAT-workspace> ```
    - Check your in right workspace ``` terraform workspace show ``` 
    - Then check your in right git branch ``` git branch ```
    - Initializes the Terraform project ``` terraform apply ``` then type ```yes```
    - For deleting all resources use ``` terraform destroy``` then type ```yes```
      
- if ``` VPC endpoint ```
    - Create new Terraform workspace ``` terraform workspace new <VPC-endpoint-workspace> ```
    - Check your in right workspace ``` terraform workspace show ``` 
    - Then check your in right git branch ``` git branch ```
    - Initializes the Terraform project ``` terraform apply ``` then type ```yes```
    - For deleting all resources use ``` terraform destroy``` then type ```yes```

In this repository:
- Creating Virtual Private Cloud (VPC)
- Four Subnets in two different Availability Zone (two public subnets, two private subnets)
- Creating Internet GateWay (IGW)
- Creating two Load Balancer:
   - First one forward traffic from public internet (IGW) to public subnets.
   - Second one forward traffic from ec2 instances in public subnets(which acts as reverse proxy), to private instances in private subnets.

   -------

Detailed explanation:

Firts creating VPC, Then creating subnets in different AZ also creating route table for public subnets.
Creating ec2 instances in each subnets & security group, Installing nginx on ec2 instances and configure it act as reverse proxy.
Creating Application Load Balancer (ALB), Associated public instances with target group, do same for private instances.
Since ec2 instances in private subnet can't reach public internet we can't install any thing on it (nginx), For this problem we have two approaches:
- Creating Network Address Translation (NAT).
- Creating VPC endpoint S3.
