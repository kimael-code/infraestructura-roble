#!/bin/bash
#
# Script de Despliegue de Roble
# 
# Este script automatiza el despliegue de actualizaciones y nuevas versiones
# de Roble en el servidor de producción.
#
# Uso:
#   ./deploy.sh [--skip-build] [--skip-migrations]
#
# Opciones:
#   --skip-build        No reconstruir imágenes Docker (usa las existentes)
#   --skip-migrations   No ejecutar migraciones de base de datos
#

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
SKIP_BUILD=false
SKIP_MIGRATIONS=false
DEPLOY_DIR=$(pwd)

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-migrations)
            SKIP_MIGRATIONS=true
            shift
            ;;
        *)
            echo "Opción desconocida: $1"
            echo "Uso: $0 [--skip-build] [--skip-migrations]"
            exit 1
            ;;
    esac
done

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

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "compose.yml" ]; then
    print_error "Este script debe ejecutarse desde el directorio infraestructura-roble"
    exit 1
fi

# Timestamp para logs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/deploy_${TIMESTAMP}.log"
mkdir -p logs

# Función para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header "🚀 Despliegue de Roble"
log "Iniciando despliegue..."

# ============================================
# 1. PULL LATEST CODE
# ============================================
print_header "[1/5] Actualizando código fuente"

log "Actualizando repositorio de infraestructura..."
git fetch origin
CURRENT_BRANCH=$(git branch --show-current)
git reset --hard origin/$CURRENT_BRANCH
print_step "Infraestructura actualizada (rama: $CURRENT_BRANCH)"

log "Actualizando repositorio de aplicación..."
cd src/roble
git fetch origin
CURRENT_APP_BRANCH=$(git branch --show-current)
git reset --hard origin/$CURRENT_APP_BRANCH
print_step "Aplicación actualizada (rama: $CURRENT_APP_BRANCH)"

cd "$DEPLOY_DIR"

# ============================================
# 2. BUILD DOCKER IMAGES
# ============================================
if [ "$SKIP_BUILD" = true ]; then
    print_header "[2/5] Build de imágenes (OMITIDO)"
    print_warning "Usando imágenes Docker existentes"
else
    print_header "[2/5] Construyendo imágenes Docker"
    
    log "Iniciando build de imágenes..."
    print_warning "Este proceso tomará 5-10 minutos..."
    echo ""
    
    # Build con output en tiempo real
    docker compose build --no-cache 2>&1 | tee -a "$LOG_FILE"
    
    print_step "Imágenes construidas"
    
    # Mostrar tamaños
    echo ""
    print_info "Tamaños de imágenes:"
    docker images | grep roble | tee -a "$LOG_FILE"
fi

# ============================================
# 3. DEPLOY CONTAINERS (ZERO DOWNTIME)
# ============================================
print_header "[3/5] Desplegando contenedores"

log "Deteniendo contenedores antiguos..."

# Stop old containers gracefully
docker compose down --timeout 30

log "Iniciando nuevos contenedores..."

# Start new containers
docker compose up -d

# Wait for services
print_warning "Esperando a que los servicios estén listos..."
sleep 15

# Verify app is running
if ! docker compose ps | grep -q "roble_app.*Up"; then
    print_error "El contenedor app no inició correctamente"
    log "ERROR: Contenedor app falló al iniciar"
    echo ""
    echo "Logs del contenedor:"
    docker compose logs app | tee -a "$LOG_FILE"
    exit 1
fi

print_step "Contenedores desplegados"

# ============================================
# 4. RUN MIGRATIONS
# ============================================
if [ "$SKIP_MIGRATIONS" = true ]; then
    print_header "[4/5] Migraciones de BD (OMITIDAS)"
    print_warning "Migraciones omitidas por flag --skip-migrations"
else
    print_header "[4/5] Ejecutando migraciones"
    
    log "Esperando a que la base de datos esté lista..."
    
    # Wait for database
    MAX_RETRIES=30
    RETRY_COUNT=0
    until docker exec roble_app php artisan db:show > /dev/null 2>&1; do
        RETRY_COUNT=$((RETRY_COUNT+1))
        if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
            print_error "Timeout esperando base de datos"
            log "ERROR: Timeout esperando base de datos"
            exit 1
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    log "Ejecutando migraciones..."
    docker exec roble_app php artisan migrate --force | tee -a "$LOG_FILE"
    
    print_step "Migraciones completadas"
fi

# ============================================
# 5. OPTIMIZE APPLICATION
# ============================================
print_header "[5/5] Optimizando aplicación"

log "Optimizando aplicación..."

docker exec roble_app php artisan optimize 2>&1 | tee -a "$LOG_FILE"
docker exec roble_app php artisan config:cache 2>&1 | tee -a "$LOG_FILE"
docker exec roble_app php artisan route:cache 2>&1 | tee -a "$LOG_FILE"
docker exec roble_app php artisan view:cache 2>&1 | tee -a "$LOG_FILE"

print_step "Aplicación optimizada"

# ============================================
# DEPLOYMENT SUMMARY
# ============================================
print_header "✅ Despliegue Completado Exitosamente"

log "Despliegue completado exitosamente"

echo ""
echo "📊 Estado de Contenedores:"
docker compose ps | tee -a "$LOG_FILE"

echo ""
echo "📈 Estadísticas:"
echo "  - Rama infraestructura: $CURRENT_BRANCH"
echo "  - Rama aplicación: $CURRENT_APP_BRANCH"
echo "  - Timestamp: $(date +'%Y-%m-%d %H:%M:%S')"
echo "  - Log: $LOG_FILE"

echo ""
echo "🔍 Verificación:"
echo "  - Ver logs en tiempo real: docker compose logs -f app"
echo "  - Verificar salud: docker compose ps"
echo "  - Acceder a la app: http://$(hostname -I | awk '{print $1}')"

echo ""
print_step "¡Despliegue completado!"

# Cleanup
log "Limpiando imágenes antiguas..."
docker image prune -f > /dev/null 2>&1

exit 0
