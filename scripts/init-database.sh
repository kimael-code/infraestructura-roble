#!/bin/bash
# init-database.sh - Script de inicialización de base de datos para Roble

set -e

# Colores
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_RED='\033[0;31m'
C_YELLOW='\033[1;33m'

echo -e "${C_BLUE}=============================================="
echo "🗄️  Inicialización de Base de Datos - Roble"
echo -e "==============================================\n${C_RESET}"

# Verificar que el contenedor app esté corriendo
if ! docker ps | grep -q roble_app; then
    echo -e "${C_RED}❌ Error: El contenedor 'roble_app' no está corriendo${C_RESET}"
    echo "   Ejecuta primero: docker compose up -d"
    exit 1
fi

# Verificar conexión a base de datos
echo -e "${C_BLUE}🔍 Verificando conexión a base de datos...${C_RESET}"
if ! docker exec roble_app php artisan db:show > /dev/null 2>&1; then
    echo -e "${C_RED}❌ Error: No se puede conectar a la base de datos${C_RESET}"
    echo "   Verifica las variables de entorno en src/roble/.env"
    exit 1
fi

echo -e "${C_GREEN}✅ Conexión a base de datos exitosa${C_RESET}\n"

# Preguntar si ejecutar migraciones
read -p "¿Ejecutar migraciones de base de datos? (s/N): " RUN_MIGRATIONS
RUN_MIGRATIONS=${RUN_MIGRATIONS,,}

if [[ "$RUN_MIGRATIONS" == "s" ]]; then
    echo -e "\n${C_BLUE}📦 Ejecutando migraciones...${C_RESET}"
    docker exec roble_app php artisan migrate --force
    echo -e "${C_GREEN}✅ Migraciones completadas${C_RESET}"
else
    echo -e "${C_YELLOW}⊘ Migraciones omitidas${C_RESET}"
fi

echo ""

# Preguntar si ejecutar seeds
read -p "¿Cargar datos iniciales (seeders)? (s/N): " RUN_SEEDS
RUN_SEEDS=${RUN_SEEDS,,}

if [[ "$RUN_SEEDS" == "s" ]]; then
    echo -e "\n${C_BLUE}🌱 Ejecutando seeders...${C_RESET}"
    docker exec roble_app php artisan db:seed --force
    echo -e "${C_GREEN}✅ Datos iniciales cargados${C_RESET}"
else
    echo -e "${C_YELLOW}⊘ Seeders omitidos${C_RESET}"
fi

echo ""
echo -e "${C_GREEN}=============================================="
echo "✅ Inicialización completada exitosamente!"
echo -e "==============================================\n${C_RESET}"

echo "📝 Próximos pasos:"
echo "   1. Verificar que la aplicación responde: http://localhost"
echo "   2. Acceder al instalador de superusuario: http://localhost/su-installer"
echo ""
