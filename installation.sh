#!/bin/bash

set -e

echo "[1/12] Cloning project repository..."
git clone https://github.com/sshresthadh/devops-class.git
cd devops-class/

echo "[2/12] Installing NVM and Node.js 14..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install 14
nvm use 14

echo "[3/12] Installing Nginx and tmux..."
sudo apt update
sudo apt install -y nginx tmux

echo "[4/12] Installing dependencies for server..."
cd all_in_docker/server
npm install

echo "[5/12] Starting backend server on port 3001 (in background)..."
tmux new-session -d -s backend 'node index.js'

echo "[6/12] Installing dependencies for client..."
cd ../client
npm install

echo "[7/12] Building frontend..."
tmux new-session -d -s frontend 'npm run start'

echo "[8/12] Creating Nginx configs using public IP..."
PUBLIC_IP=$(curl -s ifconfig.me)

# Frontend configuration
sudo tee /etc/nginx/sites-available/frontendconf > /dev/null <<EOF
server {
    listen 80;
    server_name 3.88.22.196;

    access_log /var/log/nginx/frontend_access.log;
    error_log /var/log/nginx/frontend_error.log warn;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /backend/ {
        proxy_pass http://localhost:3001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

echo "[9/12] Enabling Nginx configuration..."
sudo ln -sf /etc/nginx/sites-available/frontendconf /etc/nginx/sites-enabled/
# sudo rm -f /etc/nginx/sites-enabled/default

echo "[10/12] Testing and restarting Nginx..."
sudo nginx -t && sudo systemctl restart nginx

echo "[11/12] Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx

echo "[12/12] Setup complete!"
echo "Frontend: http://$PUBLIC_IP"
echo "Backend: http://$PUBLIC_IP/backend"
echo "To access backend tmux: tmux attach -t backend"
