# JSON EX: {"main_domain":"www.skopenow.com","alias_domains":"skopenow.com iprocess.skopenow.com","s3_init_dir":"stable","app_user":"ubuntu","app_group":"ubuntu","repository_host":"rep.skopenow.com"}
app = search(:aws_opsworks_app).first
app_path = "/var/www/#{app['shortname']}"
app_user = node['app_user']
app_group = node['app_group']



execute "update-upgrade" do
  command "sudo yum update -y && sudo yum upgrade -y"
  action :run
end

#package "Webserver" do
 # package_name "nginx"
#end
execute "install nginx" do
command "amazon-linux-extras install nginx1.12"
    action :run
end

execute "install php7.2" do
command "amazon-linux-extras install php7.2"
    action :run
end

execute "install php extensions" do
command "sudo yum install php-mbstring php-dom -y "
    action :run
end

package "FPM" do
  package_name "php-fpm"
end

package "php-cli" do
  package_name "php-cli"
end

package "php-curl" do
  package_name "php-curl"
end

package "php-zip" do
  action :install
end

package "unzip" do
  action :install
end



directory "Web root" do
  owner app_user
  mode "0755"
  group app_group
  path "/var/www/"  
end

directory "Web app root" do
  owner app_user
  mode "0755"
  group app_group
  path app_path
end

file "/home/#{app_user}/git_id_rsa" do
  owner app_user
  group app_group
  mode "0700"
  content app["app_source"]["ssh_key"]
end
#############################################################

file "/home/#{app_user}/.ssh/config" do
  owner app_user
  group app_group
  mode "0644"
  content "Host #{node['repository_host']}
HostName #{node['repository_host']}
IdentityFile /home/#{app_user}/git_id_rsa
User #{node['user_com']}
StrictHostKeyChecking no
"
end
############################################################3

#file "/root/.ssh/config" do
#  owner "root"
#  group "root"
#  mode "0600"
#  content "Host git-codecommit.*.amazonaws.com
#   User APKAR3FPJNUS7XYPMJLS
#  IdentityFile /home/#{app_user}/git_id_rsa"
#end

file "/etc/nginx/conf.d/#{node['main_domain']}.conf" do
  owner "root"
  group "root"
  mode "0644"
  content "

server {
    listen 80;
    listen [::]:80;
    root #{app_path}/public;
    index  index.php index.html index.htm;
    server_name  #{node['main_domain']} www.#{node['main_domain']};
    if ($http_x_forwarded_proto = 'http'){
    return 301 https://$host$request_uri;
    }

    location / {
    try_files $uri $uri/ /index.php?$query_string;
     }

    location ~ [^/]\.php(/|$) {
    fastcgi_split_path_info  ^(.+\.php)(/.+)$;
    fastcgi_index            index.php;
    fastcgi_pass             unix:/var/run/php-fpm/php-fpm.sock;
    include                  fastcgi_params;
    fastcgi_param   PATH_INFO       $fastcgi_path_info;
    fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

}"

end


execute "change nginx user" do
    command "sed -i 's|^\\s*user\\s*[^;]*;|user #{app_user};|' /etc/nginx/nginx.conf"
end



execute "change owner user" do
    command "sudo chown #{app_user}:#{app_group} /var/lib/nginx/ -R"
end

package "git" do
  # workaround for:
  # WARNING: The following packages cannot be authenticated!
  # liberror-perl
  # STDERR: E: There are problems and -y was used without --force-yes
  options "--force-yes" if node["platform"] == "ubuntu" && node["platform_version"] == "14.04"
end


file '/etc/php-fpm.d/www.conf' do
  action :delete
end

template '/etc/php-fpm.d/www.conf' do
  path "/etc/php-fpm.d/www.conf"
  source 'www.conf.erb'
  variables(:lis=> "/var/run/php-fpm/php-fpm.sock", :appuser=> node['app_user'], :appgroup=> node['app_group'])
end
#cookbook_file "/etc/php-fpm.d/www.conf" do
#  source "www.conf"
#  mode "0644"
#  notifies :restart, "service[nginx]"
#end

service 'php-fpm' do
  action :restart
end

service 'nginx' do
  action :restart
end
