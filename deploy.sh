#!/bin/sh
#
# deploy.sh - POSIX-compliant automated Dockerized app deployment.
# Author: Qudus (DevOps Engineer)
#

set -eu

# ================================
#   Global Variables & Setup
# ================================
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"

log() {
    printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$LOG_FILE"
}

cleanup() {
    STATUS=$?
    if [ "$STATUS" -ne 0 ]; then
        log "ERROR: Script exited with status $STATUS"
    else
        log "INFO: Script completed successfully."
    fi
}
trap 'cleanup' EXIT

# ================================
#   1. Collect User Input
# ================================
log "INFO: Starting automated deployment setup..."

printf "Enter Git repository URL: "
read REPO_URL
printf "Enter your Personal Access Token (PAT): "
read PAT
printf "Enter branch name [default: main]: "
read BRANCH
if [ -z "$BRANCH" ]; then
    BRANCH="main"
fi

printf "Enter remote server username: "
read SSH_USER
printf "Enter remote server IP address: "
read SERVER_IP
printf "Enter SSH key path (e.g. ~/.ssh/id_rsa): "
read SSH_KEY
printf "Enter application internal port (e.g. 8000): "
read APP_PORT

if [ -z "$REPO_URL" ] || [ -z "$PAT" ] || [ -z "$SSH_USER" ] || \
   [ -z "$SERVER_IP" ] || [ -z "$SSH_KEY" ] || [ -z "$APP_PORT" ]; then
    log "ERROR: One or more required inputs are missing."
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    log "ERROR: SSH key not found at $SSH_KEY"
    exit 1
fi

log "INFO: User inputs collected successfully."

# ================================
#   2. Clone or Update Repository
# ================================
REPO_NAME=$(basename "$REPO_URL" .git)

if [ -d "$REPO_NAME" ]; then
    log "INFO: Repository already exists. Pulling latest changes..."
    cd "$REPO_NAME" || exit 1
    git fetch origin "$BRANCH"
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
else
    log "INFO: Cloning repository..."
    GIT_ASKPASS=$(mktemp)
    echo "echo $PAT" > "$GIT_ASKPASS"
    chmod +x "$GIT_ASKPASS"
    GIT_ASKPASS="$GIT_ASKPASS" git clone --branch "$BRANCH" "https://$PAT@${REPO_URL#https://}" "$REPO_NAME"
    cd "$REPO_NAME" || exit 1
fi

if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
    log "INFO: Project structure looks good."
else
    log "ERROR: No Dockerfile or docker-compose.yml found."
    exit 1
fi

# ================================
#   3. Test SSH Connection
# ================================
log "INFO: Testing SSH connection..."
if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SSH_USER@$SERVER_IP" "exit" >/dev/null 2>&1; then
    log "INFO: SSH connection successful."
else
    log "ERROR: Unable to connect to remote server via SSH."
    exit 1
fi

# ================================
#   4. Prepare Remote Environment
# ================================
log "INFO: Preparing remote environment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" /bin/sh <<'EOF'
set -eu
echo "[REMOTE] Updating system packages..."
sudo apt-get update -y

echo "[REMOTE] Installing Docker if missing..."
if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sudo sh
fi

echo "[REMOTE] Installing docker-compose if missing..."
if ! command -v docker-compose >/dev/null 2>&1; then
    sudo apt-get install -y docker-compose
fi

echo "[REMOTE] Installing nginx if missing..."
if ! command -v nginx >/dev/null 2>&1; then
    sudo apt-get install -y nginx
fi

sudo systemctl enable docker nginx
sudo systemctl start docker nginx
echo "[REMOTE] Docker and Nginx setup complete."
EOF

# ================================
#   5. Deploy Dockerized App
# ================================
log "INFO: Transferring project files..."
rsync -avz -e "ssh -i $SSH_KEY" . "$SSH_USER@$SERVER_IP:/home/$SSH_USER/$REPO_NAME"

log "INFO: Building and running Docker containers..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" /bin/sh <<EOF
set -eu
cd /home/$SSH_USER/$REPO_NAME
DOCKER_CMD="docker"
if ! docker info >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

if [ -f docker-compose.yml ]; then
    sudo docker-compose down || true
    sudo docker-compose up -d --build
else
    \$DOCKER_CMD build -t $REPO_NAME .
    if \$DOCKER_CMD ps -a --format '{{.Names}}' | grep -q "^$REPO_NAME\$"; then
        \$DOCKER_CMD stop $REPO_NAME || true
        \$DOCKER_CMD rm $REPO_NAME || true
    fi
    \$DOCKER_CMD run -d --name $REPO_NAME -p $APP_PORT:$APP_PORT $REPO_NAME
fi
EOF

# ================================
#   6. Configure Nginx Reverse Proxy (FINAL FIX)
# ================================
log "INFO: Configuring Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" /bin/sh <<EOF
set -eu
APP_PORT=$APP_PORT

# Create temporary Nginx config
cat > /tmp/$REPO_NAME.nginx <<CONFIG
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \\$host;
        proxy_set_header X-Real-IP \\$remote_addr;
    }
}
CONFIG

# Move config into place and enable
sudo mv /tmp/$REPO_NAME.nginx /etc/nginx/sites-available/$REPO_NAME
sudo ln -sf /etc/nginx/sites-available/$REPO_NAME /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
EOF

# ================================
#   7. Validate Deployment
# ================================
log "INFO: Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "sudo docker ps --filter name=$REPO_NAME"
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "curl -I http://localhost" || true

log "INFO: Deployment completed successfully!"
log "INFO: Application should be accessible via: http://$SERVER_IP"
log "INFO: Log file: $LOG_FILE"

