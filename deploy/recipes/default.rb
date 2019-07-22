app = search(:aws_opsworks_app).first
app_path = "/var/www/#{app['shortname']}"
case node[:platform]
when 'ubuntu', 'debian'
  app_user = node['deb_app_user']
  app_group = node['deb_app_group']
else
  app_user = node['app_user']
  app_group = node['app_group']
end

application app_path do
  #javascript "4"
  environment.update(app["environment"])

#  git app_path do
#    user app_user
#    group app_group
#    repository app["app_source"]["url"]
#    #revision app["app_source"]["revision"]
#  end

  execute 'git clone' do
    user app_user
    group app_group
    cwd app_path
    command "git clone -b #{app['app_source']['revision']} #{app['app_source']['url']} ."
    creates "#{app_path}/.git"
  end

  execute 'git reset' do
    user app_user
    group app_group
    cwd app_path
    command "git reset --hard"
    ignore_failure true
  end

  execute 'fetch data' do
    user app_user
    group app_group
    cwd app_path
    command "git fetch"
  end

  execute 'switch branch' do
    user app_user
    group app_group
    cwd app_path
    command "git checkout #{app['app_source']['revision']}"
  end

  execute 'git pull' do
    user app_user
    group app_group
    cwd app_path
    command "git pull"
  end
end



file "#{app_path}/com.sh" do
mode '0777'
owner app_user
group app_group
content "
sudo yum install php-cli php-zip wget unzip -y
cd ~
curl -sS https://getcomposer.org/installer -o composer-setup.php
HASH='$(wget -q -O - https://composer.github.io/installer.sig)'
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
sudo mv -f /usr/local/bin/composer  /usr/bin/composer
cd '#{app_path}'
composer require guzzlehttp/guzzle
"
end

execute "#{app_path}/com.sh" do
  command "sh #{app_path}/com.sh"
  action :run
end


service 'php-fpm' do
  action :restart
end

service 'nginx' do
  action :restart
end
