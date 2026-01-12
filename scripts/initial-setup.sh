#!/bin/bash
#
# Script de Configuración Inicial de Roble en Servidor de Producción
# 
# Este script automatiza el primer despliegue de Roble en un servidor limpio.
# Debe ejecutarse UNA SOLA VEZ durante la instalación inicial.
#
# Uso:
#   ./initial-setup.sh
#

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
print_header() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Verificar que se ejecuta como usuario correcto
if [ "$EUID" -eq 0 ]; then 
   print_error "No ejecutes este script como root. Usa un usuario regular con permisos de Docker."
   exit 1
fi

print_header "Configuración Inicial de Roble"

# ============================================
# 1. VERIFICAR DEPENDENCIAS
# ============================================
print_header "[1/7] Verificando dependencias del sistema"

# Verificar Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado"
    echo "Instala Docker primero: https://docs.docker.com/engine/install/"
    exit 1
fi
print_step "Docker instalado: $(docker --version)"

# Verificar Docker Compose
if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose no está instalado"
    exit 1
fi
print_step "Docker Compose instalado: $(docker compose version)"

# Verificar Git
if ! command -v git &> /dev/null; then
    print_error "Git no está instalado"
    exit 1
fi
print_step "Git instalado: $(git --version)"

# Verificar rsync
if ! command -v rsync &> /dev/null; then
    print_warning "rsync no está instalado, instalando..."
    
    # Detectar gestor de paquetes y sistema operativo
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update && sudo apt-get install -y rsync
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL 8+/CentOS 8+
        sudo dnf install -y rsync
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 7 and older
        sudo yum install -y rsync
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S --noconfirm rsync
    elif command -v zypper &> /dev/null; then
        # openSUSE/SLES
        sudo zypper install -y rsync
    elif command -v apk &> /dev/null; then
        # Alpine Linux
        sudo apk add rsync
    else
        print_error "No se pudo detectar el gestor de paquetes"
        print_warning "Por favor instala rsync manualmente:"
        echo "  - Debian/Ubuntu: sudo apt-get install rsync"
        echo "  - RHEL/CentOS:   sudo yum install rsync"
        echo "  - Fedora:        sudo dnf install rsync"
        echo "  - Arch:          sudo pacman -S rsync"
        echo "  - openSUSE:      sudo zypper install rsync"
        echo "  - Alpine:        sudo apk add rsync"
        exit 1
    fi
fi
print_step "rsync instalado"

# Verificar permisos de Docker
if ! docker ps &> /dev/null; then
    print_error "El usuario actual no tiene permisos para usar Docker"
    echo "Ejecuta: sudo usermod -aG docker $USER"
    echo "Luego cierra sesión y vuelve a entrar"
    exit 1
fi
print_step "Permisos de Docker OK"

# ============================================
# 2. CONFIGURAR DIRECTORIO DE TRABAJO
# ============================================
print_header "[2/7] Configurando directorio de trabajo"

# Solicitar directorio de instalación
read -p "Directorio de instalación [/opt/roble]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/opt/roble}

# Crear directorio si no existe
if [ ! -d "$INSTALL_DIR" ]; then
    print_warning "Creando directorio $INSTALL_DIR..."
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
print_step "Directorio de trabajo: $INSTALL_DIR"

# ============================================
# 3. CLONAR REPOSITORIOS
# ============================================
print_header "[3/7] Clonando repositorios"

# Solicitar URLs de repositorios
read -p "URL del repositorio de infraestructura: " INFRA_REPO
read -p "URL del repositorio de aplicación: " APP_REPO

# Clonar infraestructura
if [ ! -d "infraestructura-roble" ]; then
    print_warning "Clonando repositorio de infraestructura..."
    git clone "$INFRA_REPO" infraestructura-roble
    print_step "Infraestructura clonada"
else
    print_warning "Repositorio de infraestructura ya existe"
fi

# Clonar aplicación
if [ ! -d "roble" ]; then
    print_warning "Clonando repositorio de aplicación..."
    git clone "$APP_REPO" roble
    print_step "Aplicación clonada"
else
    print_warning "Repositorio de aplicación ya existe"
fi

# ============================================
# 4. CONFIGURAR VARIABLES DE ENTORNO
# ============================================
print_header "[4/7] Configurando variables de entorno"

cd roble

if [ ! -f ".env" ]; then
    print_warning "Configurando variables de entorno..."
    echo ""
    echo "Configura las variables de entorno para tu aplicación."
    echo "Valores recomendados para producción:"
    echo "  - DB_HOST: db"
    echo "  - DB_PORT: 5432"
    echo "  - APP_ENV: production"
    echo "  - APP_DEBUG: false"
    echo ""
    read -p "Presiona ENTER para continuar..."
    
    # Si existe install.sh, ejecutarlo
    if [ -f "install.sh" ]; then
        chmod +x install.sh
        ./install.sh
    else
        # Crear .env básico desde .env.example
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_warning "Archivo .env creado desde .env.example"
            print_warning "IMPORTANTE: Edita .env con tus valores antes de continuar"
            read -p "Presiona ENTER cuando hayas editado .env..."
        fi
    fi
    
    print_step "Variables de entorno configuradas"
else
    print_warning "Archivo .env ya existe"
fi

cd ..

# ============================================
# 5. SINCRONIZAR CÓDIGO
# ============================================
print_header "[5/7] Sincronizando código a infraestructura"

cd infraestructura-roble

# Remover enlace/directorio anterior
rm -rf src/roble

# Copiar archivos
print_warning "Copiando archivos..."
rsync -av \
  --exclude='node_modules' \
  --exclude='vendor' \
  --exclude='.git' \
  --exclude='public/build' \
  --exclude='bootstrap/ssr' \
  --exclude='storage/logs/*' \
  ../roble/ \
  src/roble/

print_step "Código sincronizado"

# ============================================
# 6. CONSTRUIR IMÁGENES DOCKER
# ============================================
print_header "[6/7] Construyendo imágenes Docker"

print_warning "Este proceso tomará 5-10 minutos..."
echo ""

docker compose build --no-cache

print_step "Imágenes Docker construidas"

# Mostrar tamaños
echo ""
echo "Tamaños de imágenes:"
docker images | grep roble

# ============================================
# 7. INICIAR SERVICIOS
# ============================================
print_header "[7/7] Iniciando servicios"

# Iniciar contenedores
print_warning "Iniciando contenedores..."
docker compose up -d

# Esperar a que los servicios estén listos
print_warning "Esperando a que los servicios estén listos..."
sleep 20

# Verificar estado
echo ""
echo "Estado de contenedores:"
docker compose ps

# Verificar que app esté corriendo
if ! docker compose ps | grep -q "roble_app.*Up"; then
    print_error "El contenedor app no inició correctamente"
    echo ""
    echo "Logs del contenedor:"
    docker compose logs app
    exit 1
fi

print_step "Servicios iniciados correctamente"

# ============================================
# INICIALIZAR BASE DE DATOS
# ============================================
print_header "Inicialización de Base de Datos"

echo ""
echo "¿Deseas inicializar la base de datos ahora?"
echo "Esto ejecutará:"
echo "  - Migraciones (crear tablas)"
echo "  - Seeders (datos iniciales)"
echo ""
read -p "¿Continuar? (S/n): " INIT_DB
INIT_DB=${INIT_DB:-S}

if [[ $INIT_DB =~ ^[Ss]$ ]]; then
    print_warning "Esperando a que la base de datos esté lista..."
    
    # Esperar a que DB esté lista
    until docker exec roble_app php artisan db:show > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo ""
    
    print_warning "Ejecutando migraciones..."
    docker exec roble_app php artisan migrate --force
    
    print_warning "Ejecutando seeders..."
    docker exec roble_app php artisan db:seed --force
    
    print_step "Base de datos inicializada"
else
    print_warning "Inicialización de BD omitida"
    echo "Puedes ejecutarla más tarde con:"
    echo "  cd $INSTALL_DIR/infraestructura-roble"
    echo "  ./scripts/init-database.sh"
fi

# ============================================
# RESUMEN FINAL
# ============================================
print_header "✅ Instalación Completada"

echo ""
echo "Roble ha sido instalado exitosamente en:"
echo "  📁 $INSTALL_DIR"
echo ""
echo "Servicios corriendo:"
docker compose ps
echo ""
echo "Próximos pasos:"
echo "  1. Accede a la aplicación en: http://$(hostname -I | awk '{print $1}')"
echo "  2. Configura SSL con certbot si es necesario: ./ssl/init-letsencrypt.sh"
echo ""
echo "Comandos útiles:"
echo "  - Ver logs:        docker compose logs -f app"
echo "  - Reiniciar:       docker compose restart"
echo "  - Detener:         docker compose down"
echo "  - Actualizar:      ./scripts/deploy.sh"
echo ""

print_step "¡Instalación completada!"
