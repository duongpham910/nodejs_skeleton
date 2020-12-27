# nodejs_skeleton

Init project

```
npx express-generator --view=ejs --git
```

Refer to https://expressjs.com/en/starter/generator.html

# Capistrano (LOCAL SIDE)

## Prerequisite

### Setup
- Gem install
- Bundle init

Make new gemfile content below and run `bundle install`. Then capify with command `cap install`

```
source 'https://rubygems.org'

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

group :development do
  gem 'capistrano', require: false
  gem 'capistrano-npm', require: false
end

```

Generate file config with command `$ cap install`. Open `Capfile` and uncomment these require below

```
# Load DSL and set up stages
require 'capistrano/setup'
require 'capistrano/deploy'
require 'capistrano/scm/git'
install_plugin Capistrano::SCM::Git
require 'capistrano/npm'
require 'capistrano/slackify'

Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
```

Next job is update file `config/deploy.rb`

```
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
```

Depend on deploy environment(in this case is staging). Open file config/deploy/staging.rb

```
set :user, 'ec2-user'
set :stage, :staging
set :ssh_options, {
  keys: %w(~/key.pem),
  forward_agent: false,
  auth_methods: %w(publickey)
}

# Pass varibale to deploy from different git branches
set :deploy_ref, ENV['DEPLOY_REF']
if fetch(:deploy_ref)
 set :branch, fetch(:deploy_ref)
else
 set :branch, 'master'
end

# Setup IP with ec2 server
server '', user: fetch(:user), roles: %w[app web]
```

# Deployment (SERVER SIDE)

## Prerequisite

### Setup
- Nginx
- PM2
- Node (& yarn or npm)

### App preparation
Create directory /var/www/nodejs_skeleton
```
sudo chmod -R 777 /www
```

Inside nodejs_skeleton dir create prerequisite folder for capistrano
```
repo
releases
shared
```

## Configuration

### Nginx

Create config file `sudo vi /etc/nginx/conf.d/nodejs_skeleton.conf `

```conf
server {
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}

```

Edit nginx.config `sudo vi /etc/nginx/nginx.conf`
```
       #  listen       80 default_server;
       #  listen       [::]:80 default_server;
       #  server_name  _;
       #  root         /usr/share/nginx/html;
```

​Check status
```
sudo nginx -t
​
Still error: nginx: [warn] conflicting server name "" on 0.0.0.0:80, ignored

```

Auto launch nginx
```
sudo chkconfig nginx on
sudo service nginx start/stop
```

### PM2
Create folder client_deploy (or put in shared if using capistrano) then create file config for PM2 like below with cluster 2 instance
```js
// Options reference: https://pm2.io/doc/en/runtime/reference/ecosystem-file/
module.exports = {
   apps : [{
     name: 'nodejs_skeleton',
     cwd: '/var/www/nodejs_skeleton/current',
     script: '/var/www/nodejs_skeleton/current/bin/www',
     exec_mode: 'cluster_mode',
     instances: 2,
     max_memory_restart: '300M',
     env: {
        NODE_ENV: 'production'
      }
    }],
};
```

### Init.d Script

- Create script name `nodejs_skeleton` with content below `/etc/init.d/nodejs_skeleton`
- Change permission: `sudo chmod 755 /etc/init.d/nodejs_skeleton`

```bash
#!/bin/bash
# chkconfig: 2345 98 02
#
# description: PM2 next gen process manager for Node.js
# processname: pm2
# GIST: https://gist.github.com/zuk/8852246
### BEGIN INIT INFO
# Provides:          pm2
# Required-Start:
# Required-Stop:
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description: PM2 init script
# Description: PM2 is the next gen process manager for Node.js
### END INIT INFO

NAME=nodejs_skeleton
PM2=/usr/local/bin/pm2
NODE=/usr/local/bin/node
USER=ec2-user
CONFIG_FILE_PATH=/home/ec2-user/client_deploy/ecosystem.config.js

export PATH=/usr/local/bin:$PATH
export PM2_HOME="/home/ec2-user/.pm2"

get_user_shell() {
    local shell
    shell=$(getent passwd "${1:-$(whoami)}" | cut -d: -f7 | sed -e 's/[[:space:]]*$//')

    if [[ $shell == *"/sbin/nologin" ]] || [[ $shell == "/bin/false" ]] || [[ -z "$shell" ]];
    then
      shell="/bin/bash"
    fi

    echo "$shell"
}

super() {
    local shell
    shell=$(get_user_shell $USER)
    su - "$USER" -s "$shell" -c "PATH=$PATH; PM2_HOME=$PM2_HOME $*"
}

start() {
    echo "Starting $NAME"
    super $PM2 start $CONFIG_FILE_PATH --update-env
}

stop() {
    super $NODE $PM2 kill
}

restart() {
    echo "Restarting $NAME"
    stop
    start
}

reload() {
    echo "Reloading $NAME"
    super $PM2 reload all
}

status() {
    echo "Status for $NAME:"
    super $NODE $PM2 list
    RETVAL=$?
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: {start|stop|status|restart}"
        exit 1
        ;;
esac
exit $RETVAL
```

**Commands**
Like commands of webserver, ex: nginx. If error happen can stop/start or restart.

- Start PM2
```
sudo /etc/init.d/nodejs_skeleton start
```

- Stop PM2
```
sudo /etc/init.d/nodejs_skeleton stop
```

- Restart PM2
```
sudo /etc/init.d/nodejs_skeleton restart
```

- Check Status
```
sudo /etc/init.d/nodejs_skeleton status
```

## Deploy

```
cap staging deploy // Deploy code base from develop branch
cap staging deploy DEPLOY_REF=A // Deploy code from branch A
```
