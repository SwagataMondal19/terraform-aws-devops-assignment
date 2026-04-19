# terraform-aws-devops-assignment
AWS DevOps Assignment – Terraform Implementation

Infrastructure

Provisioned a VPC with both public and private subnets using Terraform
Configured IGW and route tables to enable internet access for public resources
Created security groups to control traffic:
Allowed HTTP (port 80) access from the internet to the Application Load Balancer
Allowed traffic from ALB to application instances in private subnet
Implemented IAM roles and instance profiles:
Attached permissions for AWS Systems Manager  for secure access (no SSH)
Attached Amazon CloudWatch Agent policy for monitoring
Configured an ALB to distribute incoming traffic across instances
Created a Target Group and registered Auto Scaling instances for load balancing
Deployed an Auto Scaling Group (min: 1, max: 2) to ensure high availability and fault tolerance
Utilized a Launch Template to define instance configuration including AMI, instance type, IAM role, and user_data scripts
Enabled health checks between ALB and instances to ensure only healthy instances receive traffic
