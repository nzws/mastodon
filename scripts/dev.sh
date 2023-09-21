set -eu

docker compose -f docker-compose.dev.yml up -d

bundle install
yarn install

# RAILS_ENV=development ./bin/rails db:setup

RAILS_ENV=development ./bin/rails db:migrate

gem install foreman
foreman start -f Procfile.dev
