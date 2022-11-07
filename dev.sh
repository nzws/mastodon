set -eu

docker compose -f docker-compose.dev.yml up -d

bundle install
yarn install

RAILS_ENV=development ./bin/rails db:setup

gem install foreman
foreman start -f Procfile.dev
