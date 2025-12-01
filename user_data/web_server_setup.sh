#!/bin/bash
# Update and install Apache
yum update -y
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create a simple HTML page showing instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "<h1>Welcome to TechCorp Web Server - Instance: $INSTANCE_ID</h1>" > /var/www/html/index.html
