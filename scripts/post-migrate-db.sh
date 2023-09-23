set -eu

docker run --rm -e RAILS_ENV=production --env-file ./scripts/.env.production.nzws ghcr.io/nzws/don.nzws.me:production-arm64 bundle exec rake db:migrate
