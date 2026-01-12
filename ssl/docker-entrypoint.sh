#!/bin/sh
set -e

# Script de entrada para Nginx
# Maneja certificados SSL: usa mkcert para localhost, Let's Encrypt para producción, o autofirmados como fallback

CERT_PATH="/etc/letsencrypt/live/${SERVER_NAME}"

echo "==> Iniciando configuración SSL para ${SERVER_NAME}..."

# Crear directorio si no existe
mkdir -p "$CERT_PATH"

# Verificar si existen certificados válidos
if [ -f "$CERT_PATH/fullchain.pem" ] && [ -f "$CERT_PATH/privkey.pem" ]; then
    echo "==> Certificados SSL encontrados para ${SERVER_NAME}"
    
    # Verificar si son certificados de mkcert (buscar el emisor mkcert)
    if openssl x509 -in "$CERT_PATH/fullchain.pem" -noout -issuer 2>/dev/null | grep -q "mkcert"; then
        echo "==> Usando certificados de mkcert - El navegador debería confiar sin advertencias"
    else
        echo "==> Usando certificados encontrados"
    fi
else
    echo "==> No se encontraron certificados SSL para ${SERVER_NAME}"
    echo "==> Generando certificados autofirmados temporales..."
    
    # Generar certificado autofirmado válido por 365 días
    openssl req -x509 -nodes -newkey rsa:4096 \
        -days 365 \
        -keyout "$CERT_PATH/privkey.pem" \
        -out "$CERT_PATH/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=${SERVER_NAME}" \
        -addext "subjectAltName=DNS:${SERVER_NAME},DNS:localhost"
    
    echo "==> Certificados autofirmados generados"
    echo "==> ADVERTENCIA: El navegador mostrará advertencias de seguridad"
    echo "==> NOTA: Para producción, ejecute init-letsencrypt.sh para Let's Encrypt"
fi

# Ejecutar el entrypoint original de nginx (procesa templates y arranca nginx)
exec /docker-entrypoint.sh "$@"
