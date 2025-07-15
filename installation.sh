#!/bin/bash

set -e

echo "[1] Cloning project repository..."
git clone https://github.com/sshresthadh/devops-class.git
cd devops-class/

echo "[2] Installing NVM and Node.js 14..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install 14
nvm use 14

echo "[3] Installing Nginx and tmux..."
sudo apt update
sudo apt install -y nginx tmux

echo "[4] Installing dependencies for server..."
cd all_in_docker/server
npm install

echo "[5] Starting backend server on port 3001 (in background)..."
# tmux new-session -d -s backend 'node index.js'

echo "[6] Installing dependencies for client..."
cd ../client
npm install

echo "[7] Building frontend..."
tmux new-session -d -s frontend 'npm run start'

echo "[8] Creating Nginx configs using public IP..."
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me || curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

if [[ -z "$PUBLIC_IP" ]]; then
    echo "❌ Could not determine public IP. Exiting."
    exit 1
fi

# Frontend configuration
cat <<'EOF' | sed "s|__PUBLIC_IP__|$PUBLIC_IP|g" | sudo tee /etc/nginx/sites-available/frontendconf > /dev/null
server {
    listen 80;
    server_name __PUBLIC_IP__;

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

echo "[9] Enabling Nginx configuration..."
sudo ln -sf /etc/nginx/sites-available/frontendconf /etc/nginx/sites-enabled/
# sudo rm -f /etc/nginx/sites-enabled/default

echo "[10] Testing and restarting Nginx..."
sudo nginx -t && sudo systemctl restart nginx

echo "[11] Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx

echo "Frontend: http://$PUBLIC_IP"
echo "Backend: http://$PUBLIC_IP/backend"
echo "To access frontend tmux: tmux attach -t frontend"
# echo "To access backend tmux: tmux attach -t backend"

echo "[13] Running backend as service"
cat <<'EOF' | sudo tee /etc/systemd/system/backend.service > /dev/null
[Unit]
Description=Your Node.js Backend
After=network.target

[Service]
Environment=NODE_ENV=production
ExecStart=/home/ubuntu/.nvm/versions/node/v14.21.3/bin/node index.js
WorkingDirectory=/home/ubuntu/devops-class/all_in_docker/server
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=client

[Install]
WantedBy=multi-user.target
EOF

echo "[14] Running backend as service"
sudo systemctl daemon-reload
sudo systemctl start backend.service
journalctl -u backend.service | grep port

echo "[15] Installing mysql"
sudo apt update
sudo apt install mysql-server


