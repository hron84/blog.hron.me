# frozen_string_literal: true

server 'moonshine.hron.me', user: 'hron', roles: %w[app]
set :deploy_to, '/srv/www/blog.hron.me/htdocs'
set :tmp_dir, '/srv/www/blog.hron.me/tmp'
set :php_path, '/usr/bin/php7.4'

# after 'deploy:published', 'drupal:symlink:htaccess'
