#!/bin/bash
#
# Script para inicializar certificados Let's Encrypt
# Ejecutar una vez después del primer despliegue
#
# Uso: ./init-letsencrypt.sh [--staging]
#   --staging: Usar servidor de pruebas de Let's Encrypt (recomendado para testing)
#

set -e

# Verificar que docker compose esté disponible
if ! command -v docker &> /dev/null; then
    echo "Error: Docker no está instalado"
    exit 1
fi

# Cargar variables de entorno
if [ -f .env ]; then
    source .env
else
    echo "Error: No se encontró archivo .env"
    echo "Cree el archivo .env con SERVER_NAME y CERTBOT_EMAIL"
    exit 1
fi

# Validar variables requeridas
if [ -z "$SERVER_NAME" ] || [ "$SERVER_NAME" = "localhost" ]; then
    echo "Error: SERVER_NAME debe estar definido y no puede ser 'localhost'"
    echo "Ejemplo: SERVER_NAME=myapp.example.com"
    exit 1
fi

if [ -z "$CERTBOT_EMAIL" ]; then
    echo "Error: CERTBOT_EMAIL debe estar definido"
    echo "Ejemplo: CERTBOT_EMAIL=admin@example.com"
    exit 1
fi

# Parámetros de staging
STAGING_ARG=""
if [ "$1" = "--staging" ]; then
    STAGING_ARG="--staging"
    echo "==> Usando servidor de STAGING (certificados de prueba)"
fi

echo "================================================"
echo "  Inicialización de Certificados Let's Encrypt"
echo "================================================"
echo "Dominio: $SERVER_NAME"
echo "Email: $CERTBOT_EMAIL"
echo ""

# Paso 1: Verificar que nginx esté corriendo
echo "==> Verificando que nginx esté corriendo..."
if ! docker compose ps webserver | grep -q "running"; then
    echo "Iniciando servicios..."
    docker compose up -d webserver
    sleep 5
fi

# Paso 2: Solicitar certificado
echo "==> Solicitando certificado a Let's Encrypt..."
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$CERTBOT_EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    $STAGING_ARG \
    -d "$SERVER_NAME"

# Paso 3: Recargar nginx
echo "==> Recargando nginx con el nuevo certificado..."
docker compose exec webserver nginx -s reload

echo ""
echo "================================================"
echo "  ¡Certificado instalado exitosamente!"
echo "================================================"
echo ""
echo "El certificado se renovará automáticamente."
echo "Puede verificar con: curl -I https://$SERVER_NAME"
