# Automated Docker Deployment Script (deploy.sh) #

## Overview ##

This project provides a robust, production-ready Bash script (deploy.sh) that automates the complete setup and deployment of a Dockerized application on a remote Linux server.

It handles everything — from cloning your code, preparing the server, deploying containers, setting up Nginx as a reverse proxy, and validating your deployment — all in one command.

Perfect for DevOps learners and engineers who want to streamline the deployment process without manually configuring servers.

## What the Script Does ##

The script performs these actions step-by-step:

### Collects Input ###

*Prompts you for details like:*

Git repository URL

Personal Access Token (for authentication)

Branch name (defaults to main)

SSH credentials (username, IP address, key path)

Application port (the port your app runs inside the container)

Clones the Repository

Authenticates using your PAT.

Clones the repo (or pulls the latest changes if it already exists).

Switches to the specified branch.

Checks Project Files

Automatically moves into the cloned folder.

Verifies if a Dockerfile or docker-compose.yml exists.

Logs success or failure.

Connects to the Remote Server

Tests SSH connectivity.

Ensures the server is reachable.

Executes deployment commands remotely.

Prepares the Remote Environment

Updates system packages.

Installs Docker, Docker Compose, and Nginx if they’re missing.

Adds the user to the Docker group (so you don’t need sudo).

Enables and starts all required services.

Deploys the Application

Transfers project files to the remote server.

Builds and runs your container(s).

Checks if containers are healthy and running.

Validates app accessibility on the defined port.

Configures Nginx (Reverse Proxy)

Automatically creates or updates an Nginx config file.

Forwards web traffic (HTTP) to your application port.

Tests and reloads Nginx configuration.

(Optional) Supports SSL setup with Certbot or self-signed certificates.

Validates Deployment

Confirms Docker and Nginx are active.

Verifies your app is accessible using curl or wget.

Logs all outcomes for review.

Logging & Error Handling

Every action is logged to a timestamped file like deploy_20251021.log.

Includes cleanup for failed steps.

Returns meaningful exit codes for debugging.

## Idempotency (Safe Re-runs) ##

Can be safely re-run without breaking your current setup.

Stops and replaces old containers gracefully.

Prevents duplicate Docker networks or Nginx configs.

Supports a --cleanup flag to remove all resources.

## Requirements ##

Linux or macOS terminal

Bash v4 or higher

Git installed locally

SSH key access to a remote Linux server

### Remote server should have: ###

Ubuntu/Debian-based OS

Internet access

Permission to install packages

## Usage ##

### Make the script executable: ###

chmod +x deploy.sh


### Run the script: ###

./deploy.sh


### Follow the prompts: ###

Enter your Git repo URL and Personal Access Token.

Provide remote server SSH details. 

Specify the internal container port (e.g., 8000).

### Optional cleanup: ###

./deploy.sh --cleanup

## Log Files ##

All logs are automatically saved in the project directory under names like:

deploy_20251021.log


Each log records success, failure, and timestamp for every operation, helping you trace any issues.

## Example Run ##
$ ./deploy.sh
Enter Git repository URL: https://github.com/qudusolamide/myapp.git
Enter your Personal Access Token (PAT): *************
Enter branch name (default: main): main
Enter remote server username: ubuntu
Enter remote server IP: 13.57.22.101
Enter path to SSH key: /home/qudus/.ssh/id_rsa
Enter internal application port: 8000


## The script will: ##

Clone your repo

Connect to your EC2 or VPS

Install Docker + Nginx

Build and run the app

Set up Nginx reverse proxy

Confirm deployment

## Cleanup ##

If you want to remove the deployed app, Docker containers, and Nginx configuration:

./deploy.sh --cleanup


This ensures a clean rollback without leaving old containers or files behind.

License

This project is open-source under the MIT License — feel free to modify and use it in your own projects.

Author

Dosunmu Qudus
Pharmacist | Aspiring DevOps Engineer
LinkedIn

Passionate about automating everything in the cloud.

Would you like me to include a diagram (in markdown format) showing the deployment flow — like:
“Local System → Remote Server → Docker → Nginx → Browser”?
It’ll make your README look even more professional for GitHub.
