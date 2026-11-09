#!/usr/bin/env bash
# db/aplicar.sh — aplica todas las migraciones en orden sobre faramantenimiento (MariaLocal)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIG="$ROOT/db/migrations"
CONTAINER="${MARIA_CONTAINER:-MariaLocal}"
DB="${MARIA_DATABASE:-faramantenimiento}"

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "El contenedor $CONTAINER no está en ejecución." >&2
  exit 1
fi

shopt -s nullglob
files=("$MIG"/*.sql)
if [ ${#files[@]} -eq 0 ]; then
  echo "No hay scripts en $MIG" >&2
  exit 1
fi

IFS=$'\n' sorted=($(printf '%s\n' "${files[@]}" | sort))
for f in "${sorted[@]}"; do
  echo ">>> Aplicando $(basename "$f")"
  docker exec -i "$CONTAINER" sh -c "mariadb -uroot -p\"\$MARIADB_ROOT_PASSWORD\" --default-character-set=utf8mb4 $DB" < "$f"
done
echo "Migraciones aplicadas."