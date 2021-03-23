# frozen_string_literal: true

def maintenance!(enable=true)
  execute :drush, 'state:set', 'system.maintenance_mode', enable.to_s.upcase
end

def cache_clear
  execute :drush, 'cache:rebuild'
end

def update_db
  maintenance!
  execute :drush, 'updatedb', '-y', '--cache-clear', '--post-updates'
  cache_clear
end

namespace :load do
  task :defaults do
    set :drupal_root, 'web'
  end
end

namespace :composer do
  task :install do
    on roles(:app) do
      within release_path do
        execute :composer, 'install', '--no-progress', '--no-interaction', '--prefer-dist'
      end
    end
  end
end

namespace :drupal do
  task :set_paths do
    SSHKit.config.command_map[:drupal] = "#{fetch(:php_path, '/usr/bin/php')} -d memory_limit=-1 #{shared_path}/vendor/bin/drupal"
    SSHKit.config.command_map[:drush] = "#{fetch(:php_path, '/usr/bin/php')} -d memory_limit=-1 #{shared_path}/vendor/bin/drush"
    SSHKit.config.command_map[:composer] = "#{fetch(:php_path, '/usr/bin/php')} -d memory_limit=-1 -d allow_url_fopen=1 #{release_path}/composer.phar"
  end

  namespace :site do
    task :backup do
      # TODO: Rewrite me when https://www.drupal.org/project/backup_migrate/issues/2968766 closed
      on roles(:app) do
        within current_path.join(fetch(:drupal_root)) do
          execute :drush, 'eval', %{'backup_migrate_perform_backup("default_db", "private_files", []);'}
        end
      end
    end

    task :setup do
      invoke 'drupal:set_paths'

      on roles(:app) do
        within release_path.join(fetch(:drupal_root)) do
          execute :drush, 'site:install', "--root=#{current_path.join(fetch(:drupal_root))}", '--locale=hu', '--account-name=sevadmin', '--account-pass=egyesek11', '--account-mail=hirek@gysev.hu', '--site-mail=hirek@gysev.hu', '-y', 'macroweb_drupal_skeleton'
          execute :drush, 'config:set', '-y', 'system.site', 'uuid', '2b2647e2-93a7-4d46-a75d-deeb8c7a59a4'
          execute :drush, 'config:set', '-y', 'language.entity.hu', 'uuid', 'f8d8cff5-5da8-4419-8f18-93f01ed3326c'
          execute :drush, 'config:import', "--root=#{release_path.join(fetch(:drupal_root))}", '-y'
          execute :drush,  'locale:import:all', "--root=#{release_path.join(fetch(:drupal_root))}", "translations", "--override=not-customized", "--type=not-customized"
        end
      end
    end

    task :offline do
      on roles(:app) do
        if test("[[ -d #{current_path} -a -f #{shared_path.join('vendor/bin/drupal')} ]]")
          within current_path.join(fetch(:drupal_root)) do
            #execute :drupal, 'site:maintenance', 'on'
            maintenance!
          end
        end
      end
    end

    task :online do
      on roles(:app) do
        within release_path.join(fetch(:drupal_root)) do
          #execute :drupal, 'site:maintenance', 'off'
          maintenance! false
        end
      end
    end
  end

  task :update do
    on roles(:app) do
      within release_path.join(fetch(:drupal_root)) do
        update_db
        maintenance!
        execute :drush, 'config:import', "--root=#{release_path.join(fetch(:drupal_root))}", '-y'
        execute :drush,  'locale:check'
        execute :drush,  'locale:update'
        execute :drush,  'locale:import:all', "--root=#{release_path.join(fetch(:drupal_root))}", release_path.join('translations'), '--override=all', '--type=customized'
        # %w[hu de].each do |lang|
        #   execute :drush, 'locale:import', "--root=#{release_path.join(fetch(:drupal_root))}", lang, release_path.join('web/profiles/custom/macroweb_drupal_skeleton/translations/#{lang}.po'), "--override=not-customized", "--type=not-customized"
        # end
        execute :drush, 'cache:rebuild'
        execute :drush, 'config:import', "--root=#{release_path.join(fetch(:drupal_root))}", '-y'
        maintenance!

        #confsplit_profile = 'config_' + fetch(:stage).to_s[0..3]

        #execute :drush, 'config-split:import', confsplit_profile, '-y'
        maintenance! false
      end
    end
  end

  namespace :cache do
    task :clear do
      on roles(:app) do
        within release_path.join(fetch(:drupal_root)) do
          #execute :drupal, 'cache:rebuild'
          cache_clear
        end
      end
    end
  end

  namespace :symlink do
    task :htdocs do
      on roles(:app) do
        execute :rm, '-f', deploy_path.join('htdocs')
        execute :ln, '-sf', release_path, deploy_path.join('htdocs')
      end
    end

    task :htaccess do
      on roles(:app) do
        execute :rm, '-f', release_path.join('web/.htaccess')
        execute :ln, '-sf', release_path.join('htaccess.txt'), release_path.join('web/.htaccess')
      end
    end
  end

  namespace :cleanup do
    task :unharden do
      on roles(:app) do
        real_current = capture(:readlink, current_path)
        dirs = capture(:ls, '-xd', releases_path.join('*/web/sites/default')).split.find_all { |dir| !dir.match(real_current) }
        dirs.each do |default_dir|
          execute :chmod, 'u+w', default_dir
        end
      end
    end

    task :harden do
      on roles(:app) do
        real_current = capture(:readlink, current_path)
        dirs = capture(:ls, '-xd', releases_path.join('*/web/sites/default')).split.find_all { |dir| !dir.match(real_current) }
        dirs.each do |default_dir|
          execute :chmod, 'u-w', default_dir
        end
      end
    end
  end
end

after 'deploy:updating', 'drupal:set_paths'
before 'deploy:updated', 'drupal:site:offline'
after 'deploy:updated', 'composer:install'
# before 'deploy:updated', 'drupal:site:backup'
after 'deploy:updated', 'drupal:update'
after 'deploy:published', 'drupal:site:online'
after 'deploy:published', 'drupal:cache:clear'
before 'deploy:cleanup', 'drupal:cleanup:unharden'
after 'deploy:cleanup', 'drupal:cleanup:harden'
