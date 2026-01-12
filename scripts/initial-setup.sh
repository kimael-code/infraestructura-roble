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
print_header "[1/6] Verificando dependencias del sistema"

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
print_header "[2/6] Configurando directorio de trabajo"

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
# 3. CLONAR REPOSITORIO DE INFRAESTRUCTURA
# ============================================
print_header "[3/6] Clonando repositorio de infraestructura"

# Solicitar URL del repositorio de infraestructura
read -p "URL del repositorio de infraestructura: " INFRA_REPO

# Clonar infraestructura
if [ ! -d "infraestructura-roble" ]; then
    print_warning "Clonando repositorio de infraestructura..."
    git clone "$INFRA_REPO" infraestructura-roble
    print_step "Infraestructura clonada"
else
    print_warning "Repositorio de infraestructura ya existe"
fi

# Entrar al directorio de infraestructura
cd infraestructura-roble

# ============================================
# 4. CLONAR APLICACIÓN EN src/
# ============================================
print_header "[4/6] Clonando aplicación en src/"

# Solicitar URL del repositorio de aplicación
read -p "URL del repositorio de aplicación: " APP_REPO

# Crear directorio src si no existe
mkdir -p src

# Clonar aplicación directamente en src/roble
if [ ! -d "src/roble" ]; then
    print_warning "Clonando repositorio de aplicación en src/roble/..."
    git clone "$APP_REPO" src/roble
    print_step "Aplicación clonada en src/roble/"
else
    print_warning "Aplicación ya existe en src/roble/"
fi

# ============================================
# 5. CONFIGURAR VARIABLES DE ENTORNO
# ============================================
print_header "[5/6] Configurando variables de entorno"

cd src/roble

if [ ! -f ".env" ]; then
    print_warning "Configurando variables de entorno..."
    echo ""
    
    # Si existe install.sh, preguntar si quiere usarlo
    if [ -f "install.sh" ]; then
        echo "Se detectó un script de instalación personalizado (install.sh)"
        echo ""
        read -p "¿Deseas ejecutar install.sh para configurar .env? (S/n): " RUN_INSTALL
        RUN_INSTALL=${RUN_INSTALL:-S}
        
        if [[ $RUN_INSTALL =~ ^[Ss]$ ]]; then
            chmod +x install.sh
            print_warning "Ejecutando install.sh..."
            echo ""
            
            # Ejecutar install.sh y capturar el código de salida
            # Desactivamos temporalmente 'set -e' para manejar errores
            set +e
            ./install.sh
            INSTALL_EXIT_CODE=$?
            set -e
            
            if [ $INSTALL_EXIT_CODE -eq 0 ]; then
                print_step "install.sh completado exitosamente"
            else
                print_warning "install.sh terminó con código $INSTALL_EXIT_CODE"
                print_warning "Continuando con configuración manual..."
            fi
        fi
    fi
    
    # Si no existe .env después de install.sh (o se omitió), crear desde .env.example
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            print_step "Archivo .env creado desde .env.example"
            echo ""
            print_warning "IMPORTANTE: Debes editar .env con tus valores de producción"
            echo ""
            echo "Variables críticas a configurar:"
            echo "  - APP_URL: URL de tu aplicación"
            echo "  - DB_HOST: db (para Docker)"
            echo "  - DB_PORT: 5432"
            echo "  - DB_DATABASE: nombre de tu base de datos"
            echo "  - DB_USERNAME: usuario de base de datos"
            echo "  - DB_PASSWORD: contraseña segura"
            echo ""
            read -p "Presiona ENTER cuando hayas editado .env..."
        else
            print_error "No se encontró .env.example"
            print_warning "Debes crear .env manualmente antes de continuar"
            exit 1
        fi
    fi
    
    print_step "Variables de entorno configuradas"
else
    print_warning "Archivo .env ya existe"
fi

# ============================================
# CONFIGURAR .ENV DE INFRAESTRUCTURA
# ============================================
print_header "Configurando .env de infraestructura"

cd ../..

# Verificar si existe .env.example
if [ ! -f ".env.example" ]; then
    print_warning "No se encontró .env.example de infraestructura"
else
    # Crear .env si no existe
    if [ ! -f ".env" ]; then
        cp .env.example .env
        print_step ".env de infraestructura creado"
    fi
    
    # Preguntar por FORWARD_DB_PORT
    echo ""
    echo "Puerto de redirección de PostgreSQL (para acceso externo/desarrollo)"
    read -p "Puerto [5432]: " FORWARD_DB_PORT
    FORWARD_DB_PORT=${FORWARD_DB_PORT:-5432}
    
    # Solo descomentar/configurar si es diferente de 5432
    if [ "$FORWARD_DB_PORT" != "5432" ]; then
        # Descomentar y actualizar la línea
        sed -i "s~^#FORWARD_DB_PORT=.*~FORWARD_DB_PORT=$FORWARD_DB_PORT~" .env
        print_step "FORWARD_DB_PORT configurado: $FORWARD_DB_PORT"
    else
        print_step "Usando puerto default (5432), variable no necesaria"
    fi
fi

# ============================================
# 6. CONSTRUIR IMÁGENES DOCKER
# ============================================
print_header "[6/6] Construyendo imágenes Docker"

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
echo "  📁 $INSTALL_DIR/infraestructura-roble"
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
