app = search(:aws_opsworks_app).first
app_path = "/var/www/#{app['shortname']}"
app_user = "ubuntu"
app_group = "ubuntu"

application app_path do
  javascript "4"
  environment.update(app["environment"])

end

