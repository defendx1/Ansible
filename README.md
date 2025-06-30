# Ansible Semaphore Complete Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue.svg)](https://www.docker.com/)
[![SSL](https://img.shields.io/badge/SSL-Auto--Configured-green.svg)](https://letsencrypt.org/)

**Complete automated installation script for Ansible and Semaphore UI with Docker, Nginx, and SSL**

Created by **Sunil Kumar** - [Defendx1.com](https://defendx1.com)

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/defendx1/Ansible.git
cd Ansible

# Make script executable
chmod +x install-ansible-semaphore.sh

# Run installation (requires sudo)
sudo ./install-ansible-semaphore.sh
```

**That's it!** The script will ask for your domain name and handle everything else automatically.

---

## 📋 What Gets Installed

### Core Components
- ✅ **Docker & Docker Compose** - Container orchestration
- ✅ **Ansible** - Automation platform (host + container)
- ✅ **Semaphore UI** - Web interface for Ansible
- ✅ **MySQL 8.0** - Database backend
- ✅ **Nginx** - Reverse proxy and web server
- ✅ **Certbot** - SSL certificate management
- ✅ **UFW Firewall** - Security configuration

### Security Features
- 🔒 **Automatic SSL certificates** with Let's Encrypt
- 🔒 **HTTPS redirect** and security headers
- 🔒 **Firewall configuration** (SSH, HTTP, HTTPS)
- 🔒 **Auto-renewal** of SSL certificates

### Management Tools
- 📊 **Health monitoring** and checks
- 📊 **Backup scripts** with database dumps
- 📊 **Start/stop/restart** utilities
- 📊 **Systemd service** for auto-start on boot

---

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Internet    │───▶│      Nginx      │───▶│   Semaphore     │
│                 │    │   (SSL/Proxy)   │    │   Container     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                │              ┌─────────────────┐
                                │              │     MySQL       │
                                │              │   Container     │
                                │              └─────────────────┘
                                │                       │
                                │              ┌─────────────────┐
                                └─────────────▶│    Ansible      │
                                               │   Container     │
                                               └─────────────────┘
```

---

## 📁 Directory Structure

```
/opt/semaphore-docker/
├── docker-compose.yml      # Main container configuration
├── .env                    # Environment variables & passwords
├── config/
│   └── mysql.cnf          # MySQL configuration
├── ssh-keys/              # SSH keys for target servers
├── playbooks/             # Ansible playbooks
│   └── sample/            # Example playbooks
├── data/                  # Persistent data
│   ├── mysql/             # Database files
│   └── semaphore/         # Application data
└── *.sh                   # Management scripts
```

---

## 🎯 Default Configuration

| Component | Details |
|-----------|---------|
| **Semaphore URL** | `https://yourdomain.com` |
| **Default Login** | Username: `admin` / Password: `admin123` |
| **Semaphore Port** | `3005` (auto-adjusted if conflicts) |
| **MySQL Port** | `3007` (auto-adjusted if conflicts) |
| **SSL** | Auto-configured with Let's Encrypt |
| **Firewall** | UFW enabled (SSH, HTTP, HTTPS) |

---

## 🔧 Management Commands

### Service Control
```bash
# Start services
/opt/semaphore-docker/start.sh

# Stop services
/opt/semaphore-docker/stop.sh

# Restart services
/opt/semaphore-docker/restart.sh

# View logs
/opt/semaphore-docker/logs.sh

# Create backup
/opt/semaphore-docker/backup.sh
```

### Docker Commands
```bash
# Check container status
cd /opt/semaphore-docker && docker-compose ps

# Access Ansible container
docker exec -it semaphore_ansible bash

# View Semaphore logs
docker logs semaphore_app

# Restart specific service
docker-compose restart semaphore
```

### Ansible Usage
```bash
# Host system Ansible
ansible --version
ansible-playbook playbook.yml

# Container Ansible
docker exec semaphore_ansible ansible --version
docker exec semaphore_ansible ansible-playbook /ansible/sample/site.yml
```

---

## 📝 Configuration Files

### Environment Variables (.env)
```bash
MYSQL_ROOT_PASSWORD=<auto-generated>
MYSQL_PASSWORD=<auto-generated>
SEMAPHORE_ACCESS_KEY=<auto-generated>
```

### Sample Inventory (playbooks/sample/inventory.yml)
```yaml
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
```

---

## 🔐 Security Setup

### SSH Keys
1. **Generate SSH key pair:**
   ```bash
   ssh-keygen -t rsa -b 4096 -f /opt/semaphore-docker/ssh-keys/id_rsa
   ```

2. **Copy public key to target servers:**
   ```bash
   ssh-copy-id -i /opt/semaphore-docker/ssh-keys/id_rsa.pub user@target-server
   ```

3. **Set proper permissions:**
   ```bash
   chmod 600 /opt/semaphore-docker/ssh-keys/id_rsa
   chmod 644 /opt/semaphore-docker/ssh-keys/id_rsa.pub
   ```

### Firewall Rules
```bash
# View current rules
sudo ufw status

# Allow additional ports if needed
sudo ufw allow 8080/tcp
```

---

## 🚨 Troubleshooting

### Common Issues

**1. Port Conflicts**
```bash
# Check what's using ports
sudo netstat -tlnp | grep -E ':(3005|3007|80|443)'

# Script automatically detects and uses alternative ports
```

**2. SSL Certificate Issues**
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

**3. Container Not Starting**
```bash
# Check container logs
cd /opt/semaphore-docker
docker-compose logs semaphore

# Restart with fresh database
docker-compose down
docker volume rm semaphore-docker_mysql_data
docker-compose up -d
```

**4. Database Connection Issues**
```bash
# Test database connection
docker exec semaphore_mysql mysql -u semaphore -p -e "SHOW DATABASES;"

# Reset database password
docker exec semaphore_mysql mysql -u root -p -e "ALTER USER 'semaphore'@'%' IDENTIFIED BY 'newpassword';"
```

### Service Status Check
```bash
# Check all services
systemctl status nginx
systemctl status docker
systemctl status semaphore-docker

# Check container health
docker-compose ps
docker-compose logs --tail=50
```

### Log Locations
```bash
# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Container logs
docker-compose logs -f semaphore
docker-compose logs -f mysql

# System logs
journalctl -u nginx -f
journalctl -u docker -f
```

---

## 🔄 Updates and Maintenance

### Update Semaphore
```bash
cd /opt/semaphore-docker
docker-compose pull semaphore
docker-compose up -d semaphore
```

### Update All Containers
```bash
cd /opt/semaphore-docker
docker-compose pull
docker-compose up -d
```

### Backup Strategy
```bash
# Automated backup (runs via cron)
/opt/semaphore-docker/backup.sh

# Manual database backup
docker exec semaphore_mysql mysqldump -u semaphore -p semaphore > backup.sql

# Full system backup
tar -czf semaphore-full-backup.tar.gz /opt/semaphore-docker/
```

---

## 📈 Monitoring and Health Checks

### Built-in Health Checks
- **MySQL**: `mysqladmin ping`
- **Semaphore**: HTTP API endpoint `/api/ping`
- **Nginx**: Configuration test and reload

### Monitor Resources
```bash
# Container resource usage
docker stats

# System resources
htop
df -h
free -h

# Network connections
ss -tulpn | grep -E ':(3005|3007|80|443)'
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/new-feature`
3. Commit your changes: `git commit -am 'Add new feature'`
4. Push to the branch: `git push origin feature/new-feature`
5. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

- **GitHub Issues**: [https://github.com/defendx1/Ansible/issues](https://github.com/defendx1/Ansible/issues)
- **Documentation**: [Semaphore UI Docs](https://docs.semaphoreui.com/)
- **Ansible Docs**: [Official Ansible Documentation](https://docs.ansible.com/)

---

## 🏷️ Version History

- **v1.0.0** - Initial release with complete automation
- **v1.1.0** - Added SSL auto-configuration
- **v1.2.0** - Enhanced security and monitoring

---

## 🙏 Acknowledgments

- [Semaphore UI Team](https://github.com/semaphoreui/semaphore) for the excellent web interface
- [Ansible Community](https://www.ansible.com/) for the automation platform
- [Docker Inc.](https://www.docker.com/) for containerization technology
- [Let's Encrypt](https://letsencrypt.org/) for free SSL certificates

---

**Created with ❤️ by [Sunil Kumar](https://defendx1.com)**

**Repository**: https://github.com/defendx1/Ansible.git
