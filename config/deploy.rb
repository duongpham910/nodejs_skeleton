# config valid for current version and patch releases of Capistrano
lock "~> 3.14.1"

set :application, 'nodejs_skeleton'
set :repo_url, 'git@github.com:duongpham910/nodejs_skeleton.git'
set :keep_releases, 5
set :deploy_to, '/var/www/nodejs_skeleton'

namespace :deploy do
  desc 'Restart pm2'
  task :restart_app do
    on roles(:app) do
      execute 'sudo /etc/init.d/nodejs_skeleton restart'
    end
  end

  before :finished, :restart_app
end
