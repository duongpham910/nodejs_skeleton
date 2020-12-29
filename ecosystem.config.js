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
