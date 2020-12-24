module.exports = {
   apps : [{
     name: 'nodejs_skeleton',
     cwd: '/var/www/nodejs_skeleton/current',
     script: '/var/www/nodejs_skeleton/current/node_modules/.bin/nuxt',
     args: 'start -n /var/run/nodejs_skeleton.sock',
     "exec_mode": "cluster_mode",
     instances: 2,
     // autorestart: true,
     max_memory_restart: '300M',
     env: {
        NODE_ENV: 'production'
      }
    }],
};
