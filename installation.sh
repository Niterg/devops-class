#!/bin/bash

set -e

echo "[1/12] Cloning project repository..."
git clone https://github.com/sshresthadh/devops-class.git
cd devops-class/

echo "[2/12] Installing NVM and Node.js 14..."
curl -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
export NVM_DIR="$HOME/.nvm"
# Load nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 14

echo "[3/12] Installing Nginx and tmux..."
sudo apt update
sudo apt install -y nginx tmux

echo "[4/12] Installing dependencies for server..."
cd all_in_docker/server
npm install

echo "[5/12] Starting backend server on port 3001 (in background)..."
node index.js 
echo "[6/12] Installing dependencies for client..."
cd ../client
npm install

echo "[7/12] Starting frontend in tmux session..."
tmux new-session -d -s frontend 'npm run start'

echo "[8/12] Creating Nginx configs using public IP..."
PUBLIC_IP=$(curl -s ifconfig.me)

# Frontend reverse proxy
sudo tee /etc/nginx/sites-enabled/frontendconf > /dev/null <<EOF
server {
    listen 80;
    server_name $PUBLIC_IP;

    access_log /var/log/nginx/frontend_access.log;
    error_log /var/log/nginx/frontend_error.log warn;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

echo "[9/12] Removing default Nginx config (if exists)..."
sudo rm -f /etc/nginx/sites-enabled/default

echo "[10/12] Testing and restarting Nginx..."
sudo nginx -t && sudo systemctl restart nginx

echo "[11/12] Installing and running Certbot..."
sudo snap install --classic certbot

echo "[12/12] Setup complete!"
echo "Frontend: http://$PUBLIC_IP"
echo "Backend: http://$PUBLIC_IP/api"
echo "To reattach frontend tmux: tmux a -t frontend"
