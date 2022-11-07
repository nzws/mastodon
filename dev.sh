docker compose up -d -f docker-compose.dev.yml
./bin/rails db:setup

gem install foreman
foreman start -f Procfile.dev
