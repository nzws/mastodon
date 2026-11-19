echo -e "\e[33m Backup the database: \e[m"
/usr/pgsql-11/bin/pg_dump mastodon > ../backup/$(date +%Y%m%d_%H-%M-%S).sql

echo -e "\e[33m Get new codes from Git: \e[m"
git fetch origin
git reset --hard origin/don.nzws.me

echo -e "\e[33m Update deps: \e[m"
bundle install
yarn install

echo -e "\e[33m Compile static files: \e[m"
RAILS_ENV=production bundle exec rails assets:precompile

echo -e "\e[33m Migrate the database: \e[m"
RAILS_ENV=production bundle exec rails db:migrate

echo -e "\e[32m Success! \e[m"
echo -e "Use these commands on sudo user to complete the update:\n"
echo "sudo systemctl reload mastodon-web"
echo "sudo systemctl restart mastodon-sidekiq"
