# Terraform-Project


![Architecture Diagram Image](https://github.com/user-attachments/assets/8676fd4d-94b8-4c13-b95f-4dfe3295afce)


# Getting Started
- First Clone repository ``` git clone <repo-url>```
- Then which type of solution for private instance you preferred [Using NAT Gateway, Using VPC endpoint]
- if ``` NAT Gateway ```
    - Create new Terraform workspace ``` terraform workspace new <NAT-workspace> ```
    - Check your in right workspace ``` terraform workspace show ```, if not change it ``` terraform workspace select <NAT-workspace>```
    - Then check your in right git branch ``` git branch ```, if not change it ```git switch main``` or ``` git checkout main```
    - Initializes the Terraform project ``` terraform init ```
    - apply terraform file ``` terraform apply ``` then type ```yes```
    - For deleting all resources use ``` terraform destroy``` then type ```yes```
      
- if ``` VPC endpoint ```
    - Create new Terraform workspace ``` terraform workspace new <VPC-endpoint-workspace> ```
    - Check your in right workspace ``` terraform workspace show ```, if not change it ``` terraform workspace select <VPC-endpoint-workspace>```
    - Then check your in right git branch ``` git branch ```, if not change it ```git switch VPC-endpoint``` or ``` git checkout VPC-endpoint```
    - Initializes the Terraform project ``` terraform init ```
    - Initializes the Terraform project ``` terraform apply ``` then type ```yes```
    - For deleting all resources use ``` terraform destroy``` then type ```yes```
 
        -------

# In this repository:
- Creating Virtual Private Cloud (VPC)
- Four Subnets in two different Availability Zone (two public subnets, two private subnets)
- Creating Internet GateWay (IGW)
- Creating two Load Balancer:
   - First one forward traffic from public internet (IGW) to public subnets.
   - Second one forward traffic from ec2 instances in public subnets(which acts as reverse proxy), to private instances in private subnets.

   --------

# Detailed explanation:

Firts creating VPC, Then creating subnets in different AZ also creating route table for public subnets.
Creating ec2 instances in each subnets & security group, Installing nginx on ec2 instances and configure it act as reverse proxy.
Creating Application Load Balancer (ALB), Associated public instances with target group, do same for private instances.
Since ec2 instances in private subnet can't reach public internet we can't install any thing on it (nginx), For this problem we have two approaches:
- Creating Network Address Translation (NAT):
   - A NAT Gateway or NAT Instance allows instances in a private subnet to access the public internet (e.g., for software updates & install) without exposing them directly to external access.
- Creating VPC endpoint S3:
   - A VPC Gateway Endpoint for S3 allows instances in private subnets to access S3 without using the internet. It works by adding a route in the route table that directs S3 traffic through AWS's internal network instead of the public internet.
   - more secure, reduces data transfer and no cost.
