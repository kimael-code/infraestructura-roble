#!/bin/bash
# backup-database.sh - Script automático de respaldo de base de datos PostgreSQL

set -e

# Configuración
BACKUP_DIR="/opt/backups/roble"
RETAIN_DAYS=30  # Días para retener backups

# Crear directorio si no existe
mkdir -p "$BACKUP_DIR"

# Nombre del backup con fecha y hora
BACKUP_FILE="$BACKUP_DIR/roble-backup-$(date +%Y%m%d-%H%M%S).sql"

echo "📦 Creando respaldo de base de datos..."
echo "   Archivo: $BACKUP_FILE"

# Crear backup
docker exec roble_db pg_dump -U postgres roble_production > "$BACKUP_FILE"

# Comprimir backup
gzip "$BACKUP_FILE"

echo "✅ Respaldo creado: ${BACKUP_FILE}.gz"

# Limpiar backups antiguos
echo "🧹 Eliminando respaldos más antiguos de $RETAIN_DAYS días..."
find "$BACKUP_DIR" -name "roble-backup-*.sql.gz" -mtime +$RETAIN_DAYS -delete

echo "✅ Respaldo completado exitosamente"
