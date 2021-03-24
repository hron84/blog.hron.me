# frozen_string_literal: true

server 'moonshine.hron.me', user: 'hron', roles: %w[app]
set :deploy_to, '/srv/www/devblog.hron.me'
set :tmp_dir, '/srv/www/devblog.hron.me/shared/tmp'

# after 'deploy:published', 'drupal:symlink:htaccess'
