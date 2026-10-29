set -eu

source ./scripts/.env.production

pg_dump --host=$DB_HOST --port=$DB_PORT --username=$DB_USER --dbname=$DB_NAME --format=custom > ./scripts/$(date +%Y%m%d_%H-%M-%S).dump
