#!/bin/bash
# Update and install PostgreSQL
yum update -y
amazon-linux-extras enable postgresql14
yum install -y postgresql-server postgresql-contrib

# Initialize and start PostgreSQL
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql

# Set up a sample database and user
sudo -u postgres psql -c "CREATE DATABASE techcorpdb;"
sudo -u postgres psql -c "CREATE USER techcorpuser WITH ENCRYPTED PASSWORD 'Funmikay22';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE techcorpdb TO techcorpuser;"
