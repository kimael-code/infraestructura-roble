# Roble Infrastructure - Production-Ready Docker Stack

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Laravel](https://img.shields.io/badge/Laravel-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)](https://laravel.com)
[![Vue.js](https://img.shields.io/badge/Vue.js-4FC08D?style=for-the-badge&logo=vue.js&logoColor=white)](https://vuejs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**Production-grade Docker infrastructure for Laravel + Inertia.js + Vue.js applications** with automatic SSL/TLS, WebSocket support, and optimized multi-stage builds.

> Originally designed for **[Roble](https://github.com/kimael-code/roble)** - a Laravel-based framework - this infrastructure is fully reusable for any Laravel + Inertia.js + Vue.js stack.

---

## ✨ Features

- 🔒 **Automatic HTTPS/SSL** with Let's Encrypt (auto-renewal)
- 🔄 **Laravel Reverb** WebSockets over WSS
- ⚡ **Inertia.js SSR** (Server-Side Rendering)
- 📬 **Laravel Queue Workers** running in background
- 🐘 **PostgreSQL 17** with health checks
- 🚀 **Multi-stage Docker builds** (68% size reduction: 1.73GB → 552MB)
- 🔧 **Zero-downtime deployments**
- 📦 **Production-optimized** PHP-FPM + Nginx + Supervisor
- 🛡️ **Security hardened** with best practices

---

## 🚀 Quick Start

### Prerequisites

- Docker 24.0+
- Docker Compose 2.0+
- Git
- A domain name (for production SSL)

> **Note:** The `initial-setup.sh` script automatically detects and installs `rsync` on Debian/Ubuntu, RHEL/CentOS, Fedora, Arch Linux, openSUSE, and Alpine systems.

### 1. Clone and Configure

> **Note:** For production deployment, see the [Production Deployment](#production-deployment) section which uses an automated setup script.

```bash
git clone https://github.com/kimael-code/infraestructura-roble.git
cd infraestructura-roble

# Copy environment template
cp .env.example .env
```

### 2. Add Your Application

Place your Laravel application code in the `src/roble/` directory:

```bash
# Option A: Clone your application
git clone https://github.com/yourusername/your-app.git src/roble

# Option B: Copy existing application
cp -r /path/to/your/laravel/app src/roble
```

### 3. Edit Environment Variables

```bash
# Infrastructure environment (.env in root)
SERVER_NAME=myapp.example.com
CERTBOT_EMAIL=admin@example.com

DB_DATABASE=your_database
DB_USERNAME=your_user
DB_PASSWORD=your_secure_password

# Application environment (src/roble/.env)
# Configure your Laravel .env file as needed
```

### 4. Build and Deploy

```bash
# Build Docker images
docker compose build --no-cache

# Start services
docker compose up -d
```

### 5. SSL Certificate (Production)

> ⚠️ **Requirement**: Domain must be publicly accessible on port 80

```bash
# Test with staging certificates first
./ssl/init-letsencrypt.sh --staging

# If successful, get real certificate
./ssl/init-letsencrypt.sh
```

---

## 📁 Project Structure

```
.
├── compose.yml              # Service orchestration
├── app.Dockerfile           # PHP-FPM + Node.js + Supervisor
├── nginx.Dockerfile         # Nginx with SSL support
├── database.Dockerfile      # PostgreSQL 17
├── nginx/
│   └── default.conf.template   # Nginx config (SSL + WebSockets)
├── php/
│   └── php.ini              # Custom PHP configuration
├── ssl/
│   ├── docker-entrypoint.sh    # Auto-generates self-signed certs
│   └── init-letsencrypt.sh     # Let's Encrypt certificate setup
├── supervisor/
│   └── supervisord.conf     # PHP-FPM, Queues, Reverb, SSR workers
├── scripts/
│   ├── initial-setup.sh     # First-time server setup
│   ├── deploy.sh            # Automated deployment
│   ├── init-database.sh     # Database initialization
│   └── backup-database.sh   # Database backup utility
└── src/                     # Your Laravel application code
```

---

## 🐳 Services

| Service     | Description                         | Ports      |
| ----------- | ----------------------------------- | ---------- |
| `app`       | PHP-FPM, Queues, Reverb, SSR        | 9000, 8080 |
| `webserver` | Nginx (HTTP/HTTPS, WebSocket proxy) | 80, 443    |
| `db`        | PostgreSQL 17                       | 5432       |
| `certbot`   | Automatic SSL renewal               | -          |

---

## 🔧 Configuration

### Environment Variables

#### Docker Infrastructure (`.env`)

```bash
# SSL Configuration
SERVER_NAME=myapp.example.com
CERTBOT_EMAIL=admin@example.com

# Database
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=secure_password_here

# Timezone and Locale (applies to both app and database containers)
TZ=UTC                    # Options: UTC, America/New_York, Europe/London, etc.
LOCALE=en_US.UTF-8        # Options: en_US.UTF-8, es_ES.UTF-8, pt_BR.UTF-8, etc.

# Optional: Port forwarding for development
FORWARD_DB_PORT=5432
PHP_FORWARD_PORT=9000
REVERB_FORWARD_PORT=8080
```

> **Note:** The `TZ` and `LOCALE` variables are applied consistently across both the application and database containers during build time, ensuring timezone and locale consistency throughout your stack.

#### Laravel Application (`src/your-app/.env`)

```bash
APP_NAME="Your Application"
APP_ENV=production
APP_DEBUG=false

DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=secure_password_here

BROADCAST_DRIVER=reverb
QUEUE_CONNECTION=database
```

---

## 🎯 Usage

### Development

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f app

# Run artisan commands
docker compose exec app php artisan migrate
docker compose exec app php artisan queue:work
```

### Production Deployment

#### First-Time Setup

The `initial-setup.sh` script automates the entire first deployment process. It will:

- Verify system dependencies (Docker, Git, rsync)
- Clone both infrastructure and application repositories
- Configure environment variables
- Build Docker images
- Initialize database
- Start services

**Installation:**

```bash
# Download the setup script
curl -O https://raw.githubusercontent.com/kimael-code/infraestructura-roble/main/scripts/initial-setup.sh

# Make it executable
chmod +x initial-setup.sh

# Run the interactive installer
./initial-setup.sh
```

**The script will prompt you for:**

1. **Installation directory** (default: `/opt/roble`)
2. **Infrastructure repository URL** (this repo)
3. **Application repository URL** (your Laravel app)
4. **Database initialization** (yes/no)

**Example session:**

```
Directorio de instalación [/opt/roble]: /opt/myapp
URL del repositorio de infraestructura: https://github.com/kimael-code/infraestructura-roble.git
URL del repositorio de aplicación: https://github.com/yourusername/your-laravel-app.git
¿Continuar? (S/n): S
```

#### Updates

```bash
./scripts/deploy.sh
```

Features:

- Zero-downtime deployment
- Automatic code sync
- Database migrations
- Cache optimization
- Rollback on failure

Options:

```bash
./scripts/deploy.sh --skip-build        # Use existing images
./scripts/deploy.sh --skip-migrations   # Skip database migrations
```

---

## 🔒 SSL/TLS Certificates

### Development (Self-Signed)

On first start, self-signed certificates are automatically generated. Browsers will show security warnings.

### Production (Let's Encrypt)

1. Ensure domain resolves to server IP
2. Verify port 80 is accessible from internet
3. Run: `./ssl/init-letsencrypt.sh`

**Auto-renewal**: The `certbot` container checks every 12 hours and renews certificates automatically.

---

## 🚀 Performance Optimizations

### Multi-Stage Docker Build

- **Stage 1 (Builder)**: Installs dependencies, builds assets
- **Stage 2 (Production)**: Only runtime dependencies

**Result**: 68% size reduction (1.73GB → 552MB)

### PHP-FPM Tuning

Optimized `php.ini` settings for production:

- Increased memory limits
- OPcache enabled
- Realpath cache optimized

### Nginx Configuration

- HTTP/2 enabled
- Gzip compression
- Static file caching
- WebSocket proxy for Reverb

---

## 📊 Monitoring

### Health Checks

```bash
# Check service status
docker compose ps

# View application logs
docker compose logs -f app

# Check database connectivity
docker compose exec app php artisan db:show

# Verify SSL certificate
curl -I https://your-domain.com
```

### Supervisor Status

```bash
docker compose exec app supervisorctl status
```

Expected output:

```
php-fpm                          RUNNING
queue_worker                     RUNNING
reverb_worker                    RUNNING
ssr_worker                       RUNNING
```

---

## 🛠️ Useful Commands

```bash
# Restart Nginx after config changes
docker compose exec webserver nginx -s reload

# Run database migrations
docker compose exec app php artisan migrate

# Clear application cache
docker compose exec app php artisan optimize:clear

# Backup database
./scripts/backup-database.sh

# Force SSL certificate renewal
docker compose run --rm certbot renew --force-renewal
docker compose exec webserver nginx -s reload
```

---

## 🔍 Troubleshooting

### "Connection refused" on HTTPS

Check if certificate exists:

```bash
docker compose exec webserver ls -la /etc/letsencrypt/live/
```

### Let's Encrypt fails

1. Verify DNS: `nslookup your-domain.com`
2. Check port 80 is open from internet
3. Try staging first: `./ssl/init-letsencrypt.sh --staging`

### WebSockets not connecting

Verify Reverb is running:

```bash
docker compose exec app supervisorctl status reverb_worker
```

Check Reverb logs:

```bash
docker compose logs app | grep reverb
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Internet                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │   Nginx (webserver)   │
         │   - HTTP/HTTPS        │
         │   - SSL Termination   │
         │   - WebSocket Proxy   │
         └───────────┬───────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐         ┌──────────────┐
│  PHP-FPM      │         │  Reverb      │
│  (port 9000)  │         │  (port 8080) │
└───────┬───────┘         └──────────────┘
        │
        │  ┌─────────────────────────┐
        ├──┤  Queue Workers          │
        │  └─────────────────────────┘
        │
        │  ┌─────────────────────────┐
        ├──┤  SSR Worker (Inertia)   │
        │  └─────────────────────────┘
        │
        ▼
┌───────────────┐
│  PostgreSQL   │
│  (port 5432)  │
└───────────────┘
```

---

## 📝 Customization

### For Your Application

1. **Clone this repository** as your infrastructure base
2. **Update image names** in `compose.yml`:
   ```yaml
   image: yourorg/yourapp-app
   image: yourorg/yourapp-webserver
   image: yourorg/yourapp-db
   ```
3. **Customize Dockerfiles** as needed for your application
4. **Configure environment** variables for your domain and database

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Maikel Carballo**

- GitHub: [@kimael-code](https://github.com/kimael-code)
- GitLab: [@profemaik](https://gitlab.com/profemaik)
- LinkedIn: [Maikel Carballo](https://linkedin.com/in/maikel-c-2314311a1)
- Bluesky: [@maikel-dev](https://bsky.app/profile/maikel-dev.bsky.social)

---

## 🙏 Acknowledgments

- Originally built for the [Roble](https://github.com/kimael-code/roble) framework
- Designed for production deployment of Laravel + Inertia.js applications
- Inspired by modern DevOps best practices
- Optimized for performance and security

---

## 📚 Related Projects

- [Laravel](https://laravel.com) - The PHP Framework
- [Inertia.js](https://inertiajs.com) - The Modern Monolith
- [Vue.js](https://vuejs.org) - The Progressive JavaScript Framework
- [Laravel Reverb](https://reverb.laravel.com) - WebSockets for Laravel

---

**⭐ If you find this project useful, please consider giving it a star!**
