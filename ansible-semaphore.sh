#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}    Ansible Semaphore Complete Setup    ${NC}"
echo -e "${BLUE}         by Sunil Kumar                  ${NC}"
echo -e "${BLUE}         Defendx1.com                    ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

echo -e "${YELLOW}Enter your domain name for Ansible Semaphore:${NC}"
read -p "Domain (e.g., ansible.defendx1.com): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    error "Domain name is required"
fi

echo -e "\n${GREEN}Domain set to: $DOMAIN${NC}\n"

INSTALL_DIR="/opt/semaphore-docker"
SEMAPHORE_PORT="3005"
MYSQL_PORT="3007"

MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
MYSQL_PASSWORD=$(openssl rand -base64 32)
SEMAPHORE_ACCESS_KEY=$(openssl rand -base64 32)

log "Updating system packages..."
apt update && apt upgrade -y

log "Installing required packages..."
apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release nginx certbot python3-certbot-nginx ufw net-tools

log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

log "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

log "Starting and enabling Docker..."
systemctl start docker
systemctl enable docker

log "Installing Ansible on host..."
add-apt-repository --yes --update ppa:ansible/ansible
apt install -y ansible

log "Checking for port conflicts..."
if netstat -tlnp | grep -q ":${SEMAPHORE_PORT} "; then
    SEMAPHORE_PORT="3006"
fi
if netstat -tlnp | grep -q ":${MYSQL_PORT} "; then
    MYSQL_PORT="3008"
fi

log "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

log "Cleaning up existing containers..."
docker stop semaphore_app semaphore_mysql semaphore_ansible 2>/dev/null || true
docker rm semaphore_app semaphore_mysql semaphore_ansible 2>/dev/null || true

log "Creating directory structure..."
mkdir -p config ssh-keys playbooks data/mysql data/semaphore

log "Creating environment file..."
cat > .env << EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
SEMAPHORE_ACCESS_KEY=${SEMAPHORE_ACCESS_KEY}
EOF

log "Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: semaphore_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: semaphore
      MYSQL_USER: semaphore
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./config/mysql.cnf:/etc/mysql/conf.d/mysql.cnf:ro
    ports:
      - "MYSQL_PORT_PLACEHOLDER:3306"
    networks:
      - semaphore_net
    command: --default-authentication-plugin=mysql_native_password --skip-log-bin
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10
      interval: 30s

  semaphore:
    image: semaphoreui/semaphore:latest
    container_name: semaphore_app
    restart: unless-stopped
    ports:
      - "SEMAPHORE_PORT_PLACEHOLDER:3000"
    environment:
      SEMAPHORE_DB_USER: semaphore
      SEMAPHORE_DB_PASS: ${MYSQL_PASSWORD}
      SEMAPHORE_DB_HOST: mysql
      SEMAPHORE_DB_PORT: 3306
      SEMAPHORE_DB_DIALECT: mysql
      SEMAPHORE_DB: semaphore
      SEMAPHORE_PLAYBOOK_PATH: /tmp/semaphore/
      SEMAPHORE_ADMIN_PASSWORD: admin123
      SEMAPHORE_ADMIN_NAME: admin
      SEMAPHORE_ADMIN_EMAIL: admin@DOMAIN_PLACEHOLDER
      SEMAPHORE_ADMIN: admin
      SEMAPHORE_ACCESS_KEY_ENCRYPTION: ${SEMAPHORE_ACCESS_KEY}
      SEMAPHORE_LDAP_ACTIVATED: 'no'
      SEMAPHORE_WEB_HOST: https://DOMAIN_PLACEHOLDER
      TZ: UTC
    volumes:
      - semaphore_data:/etc/semaphore:rw
      - ./ssh-keys:/root/.ssh:ro
      - ./playbooks:/tmp/semaphore:rw
    networks:
      - semaphore_net
    depends_on:
      mysql:
        condition: service_healthy

  ansible:
    image: willhallonline/ansible:latest
    container_name: semaphore_ansible
    restart: unless-stopped
    volumes:
      - ./playbooks:/ansible:rw
      - ./ssh-keys:/root/.ssh:ro
      - ansible_cache:/tmp/ansible
    networks:
      - semaphore_net
    environment:
      - ANSIBLE_HOST_KEY_CHECKING=False
      - ANSIBLE_STDOUT_CALLBACK=yaml
      - ANSIBLE_FORCE_COLOR=1
    command: tail -f /dev/null

networks:
  semaphore_net:
    name: semaphore_network
    driver: bridge

volumes:
  mysql_data:
    driver: local
  semaphore_data:
    driver: local
  ansible_cache:
    driver: local
EOF

sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" docker-compose.yml
sed -i "s/SEMAPHORE_PORT_PLACEHOLDER/${SEMAPHORE_PORT}/g" docker-compose.yml
sed -i "s/MYSQL_PORT_PLACEHOLDER/${MYSQL_PORT}/g" docker-compose.yml

log "Creating MySQL configuration..."
cat > config/mysql.cnf << 'EOF'
[mysqld]
default-authentication-plugin=mysql_native_password
bind-address=0.0.0.0
port=3306
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_connections=200
innodb_buffer_pool_size=256M
skip-name-resolve=1
sql_mode=STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO

[client]
default-character-set=utf8mb4
EOF

log "Creating sample playbook..."
mkdir -p playbooks/sample
cat > playbooks/sample/inventory.yml << 'EOF'
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 192.168.1.10
        web2:
          ansible_host: 192.168.1.11
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: /root/.ssh/id_rsa
EOF

cat > playbooks/sample/site.yml << 'EOF'
---
- name: Sample playbook
  hosts: all
  become: true
  tasks:
    - name: Update package cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
    
    - name: Install basic packages
      package:
        name:
          - curl
          - wget
          - htop
          - vim
        state: present
    
    - name: Create sample file
      copy:
        content: "Hello from Ansible Semaphore!"
        dest: /tmp/semaphore-test.txt
        mode: '0644'
    
    - name: Display system info
      debug:
        msg: "System {{ ansible_hostname }} is running {{ ansible_distribution }} {{ ansible_distribution_version }}"
EOF

log "Setting permissions..."
chmod 700 ssh-keys/
chmod 755 playbooks/
chown -R root:root .

log "Configuring nginx..."
cat > "/etc/nginx/sites-available/${DOMAIN}" << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    client_max_body_size 100M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    location / {
        proxy_pass http://127.0.0.1:${SEMAPHORE_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        proxy_buffering on;
        proxy_buffer_size 8k;
        proxy_buffers 8 8k;
    }
    
    location /ping {
        access_log off;
        return 200 "pong";
        add_header Content-Type text/plain;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://127.0.0.1:${SEMAPHORE_PORT};
        proxy_set_header Host \$host;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
EOF

ln -sf "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"

log "Testing nginx configuration..."
nginx -t

log "Starting nginx..."
systemctl start nginx
systemctl enable nginx
systemctl reload nginx

log "Setting up firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw reload

log "Starting Docker services..."
docker-compose up -d

log "Waiting for services to initialize..."
sleep 45

log "Setting up SSL certificate..."
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN} --redirect

log "Testing SSL renewal..."
certbot renew --dry-run

log "Creating management scripts..."
cat > start.sh << 'EOF'
#!/bin/bash
cd /opt/semaphore-docker
docker-compose up -d
EOF

cat > stop.sh << 'EOF'
#!/bin/bash
cd /opt/semaphore-docker
docker-compose down
EOF

cat > restart.sh << 'EOF'
#!/bin/bash
cd /opt/semaphore-docker
docker-compose restart
EOF

cat > logs.sh << 'EOF'
#!/bin/bash
cd /opt/semaphore-docker
docker-compose logs -f
EOF

cat > backup.sh << EOF
#!/bin/bash
BACKUP_DIR="/opt/semaphore-backups"
BACKUP_FILE="semaphore-backup-\$(date +%Y%m%d-%H%M%S).tar.gz"
mkdir -p \$BACKUP_DIR
cd /opt/semaphore-docker
docker-compose exec mysql mysqldump -u semaphore -p${MYSQL_PASSWORD} semaphore > backup.sql
tar -czf "\$BACKUP_DIR/\$BACKUP_FILE" data/ config/ ssh-keys/ playbooks/ backup.sql docker-compose.yml .env
rm backup.sql
echo "Backup created: \$BACKUP_DIR/\$BACKUP_FILE"
EOF

chmod +x *.sh

log "Creating systemd service..."
cat > "/etc/systemd/system/semaphore-docker.service" << EOF
[Unit]
Description=Semaphore Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable semaphore-docker.service

log "Final health check..."
sleep 30

for i in {1..15}; do
    if curl -s https://${DOMAIN}/api/ping >/dev/null 2>&1; then
        log "✅ Semaphore is responding on HTTPS!"
        break
    elif curl -s http://${DOMAIN}/api/ping >/dev/null 2>&1; then
        log "✅ Semaphore is responding on HTTP!"
        break
    else
        warn "Attempt $i: Waiting for Semaphore..."
        sleep 10
    fi
done

clear
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}    🎉 INSTALLATION COMPLETED! 🎉      ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo
echo -e "${BLUE}🌐 Access URL:${NC} https://${DOMAIN}"
echo -e "${BLUE}🔐 Login Credentials:${NC}"
echo -e "   Username: ${YELLOW}admin${NC}"
echo -e "   Password: ${YELLOW}admin123${NC}"
echo
echo -e "${BLUE}📊 Database Info:${NC}"
echo -e "   MySQL Port: ${YELLOW}${MYSQL_PORT}${NC}"
echo -e "   Root Password: ${YELLOW}${MYSQL_ROOT_PASSWORD}${NC}"
echo -e "   Semaphore DB Password: ${YELLOW}${MYSQL_PASSWORD}${NC}"
echo
echo -e "${BLUE}🐳 Docker Commands:${NC}"
echo -e "   Start: ${YELLOW}${INSTALL_DIR}/start.sh${NC}"
echo -e "   Stop: ${YELLOW}${INSTALL_DIR}/stop.sh${NC}"
echo -e "   Restart: ${YELLOW}${INSTALL_DIR}/restart.sh${NC}"
echo -e "   Logs: ${YELLOW}${INSTALL_DIR}/logs.sh${NC}"
echo -e "   Backup: ${YELLOW}${INSTALL_DIR}/backup.sh${NC}"
echo
echo -e "${BLUE}📁 Important Directories:${NC}"
echo -e "   SSH Keys: ${YELLOW}${INSTALL_DIR}/ssh-keys/${NC}"
echo -e "   Playbooks: ${YELLOW}${INSTALL_DIR}/playbooks/${NC}"
echo -e "   Configuration: ${YELLOW}${INSTALL_DIR}/config/${NC}"
echo
echo -e "${BLUE}🔧 Ansible Commands:${NC}"
echo -e "   Host: ${YELLOW}ansible --version${NC}"
echo -e "   Container: ${YELLOW}docker exec semaphore_ansible ansible --version${NC}"
echo
echo -e "${GREEN}✅ SSL Certificate: Configured and Auto-Renewal Enabled${NC}"
echo -e "${GREEN}✅ Firewall: Configured (SSH, HTTP, HTTPS)${NC}"
echo -e "${GREEN}✅ Auto-Start: Enabled on boot${NC}"
echo
echo -e "${BLUE}📝 Created by: Sunil Kumar - Defendx1.com${NC}"
echo -e "${GREEN}=========================================${NC}"

docker-compose ps
