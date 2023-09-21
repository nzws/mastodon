set -eu

docker run --rm -e SKIP_POST_DEPLOYMENT_MIGRATIONS=true -e RAILS_ENV=production --env-file ./scripts/.env.production ghcr.io/nzws/don.nzws.me:production-arm64 bundle exec rake db:migrate
