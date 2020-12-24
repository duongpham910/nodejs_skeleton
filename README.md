# nodejs_skeleton
just for normal nodejs project

# Deployment

## Prerequisite

### Setup
- Nginx
- PM2
- Node (& yarn or npm)

### Environment variables
```
export BASE_SSR_API_URL=http://localhost:3000
export BASE_API_URL=http://domain.com (or public IP)
```


## Configuration

### Nginx

```conf
upstream puma {
  server unix:/var/www/dating_today_server/tmp/sockets/puma.sock fail_timeout=0;
}

upstream nuxt_client {
  server unix:/var/run/dating_today_client.sock fail_timeout=0;
}

server {
  listen 80;
  # server_name localhost 127.0.0.1 dating_domain.com;
  server_name localhost 127.0.0.1 54.150.137.228;

  index index.html;

  access_log stdout;
  error_log  stderr warn;
  access_log /var/log/nginx/dating.access.log;
  error_log  /var/log/nginx/dating.error.log;

  location /api/ {
       proxy_pass http://puma;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
       proxy_set_header Host $host;
  }

  location / {
     proxy_pass http://nuxt_client;

     proxy_http_version 1.1;
     proxy_set_header Upgrade $http_upgrade;
     proxy_set_header Connection "upgrade";
     proxy_set_header Host $host;
     proxy_cache_bypass $http_upgrade;
  }
}
```

### PM2
Tạo thư mục client_deploy (hoặc đặt trong shared nếu dùng capistrano) rồi tạo file config cho PM2 như dưới với cluster 2 instance và chạy qua unix socket

```js
// Options reference: https://pm2.io/doc/en/runtime/reference/ecosystem-file/
module.exports = {
   apps : [{
     name: 'dating_today_client',
     cwd: '/var/www/dating_today_client',  
     script: '/var/www/dating_today_client/node_modules/.bin/nuxt',
     args: 'start -n /var/run/dating_today_client.sock',
     "exec_mode": "cluster_mode",
     instances: 2,
     max_memory_restart: '300M',
     env: {
        NODE_ENV: 'production'
      }
    }],
};
```

### Grant Access
Cấp quyền cho user `lbapp` để tạo unix socket `dating_today_client.sock` (daemon) trong run. (Cái này khi server reboot bị mất. -> Tìm cách set quyền vĩnh viễn hoặc tự động set lại khi reboot server)

```bash
$ sudo chown lbapp:lbapp /var/run
```

**Nếu đặt trong thư mục `tmp` của project thì không cần.**


### Init.d Script

- Tạo 1 Script tên `dating_today_client` như dưới trong `/etc/init.d/dating_today_client`
- Cấp quyền: `sudo chmod 755 /etc/init.d/dating_today_client`

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

NAME=dating_today_client
PM2=/usr/local/bin/pm2
NODE=/usr/local/bin/node
USER=lbapp
SOCKET_FILE_PATH=/var/run/dating_today_client.sock
# TODO: Should move config file to shared directory?
CONFIG_FILE_PATH=/home/lbapp/client_deploy/ecosystem.config.js

export PATH=/usr/local/bin:$PATH
export PM2_HOME="/home/lbapp/.pm2"

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
    for i in {0..30}; do
        echo "Waiting for creating socket file..."
        if [ -e $SOCKET_FILE_PATH ]; then
            break
        fi
        sleep 1
    done
    chmod o+w $SOCKET_FILE_PATH
}

stop() {
    super $NODE $PM2 kill
}

restart() {
    if [ -e $SOCKET_FILE_PATH ]; then
       rm -rf $SOCKET_FILE_PATH
    fi
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

**Một số lệnh**
Cũng giống như các câu lệnh của webserver như nginx. Khi bị lỗi cũng có thể stop/start hoặc restart.

- Start PM2
```
sudo /etc/init.d/dating_today_client start
```

- Stop PM2
```
sudo /etc/init.d/dating_today_client stop
```

- Restart PM2
```
sudo /etc/init.d/dating_today_client restart
```

- Check Status
```
sudo /etc/init.d/dating_today_client status
```


## Deploy

1. Chạy yarn (npm) install
```
yarn install
```
2. Yarn (npm) Build (build nuxt)
```
sudo yarn nuxt build
```
3. Chạy script đã tạo ở trên để khởi động lại pm2
```
sudo /etc/init.d/dating_today_client restart
```