# frozen_string_literal: true

server 'moonshine.hron.me', user: 'hron', roles: %w[app]
set :deploy_to, '/srv/www/blog.hron.me'
set :tmp_dir, '/srv/www/blog.hron.me/shared/tmp'

# after 'deploy:published', 'drupal:symlink:htaccess'
