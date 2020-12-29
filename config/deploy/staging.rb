set :user, 'ec2-user'
set :stage, :staging
set :ssh_options, {
  keys: %w(~/workspace/skeleton/nodejs_skeleton/nodejs_skeleton_v1.pem),
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
server '13.212.58.96', user: fetch(:user), roles: %w[app web]
