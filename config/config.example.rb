Configuration.for('database') {
  database_name 'scraper'
  database_user 'dboeloe'
  database_password 'dboeloe'
  database_host 'localhost'
}

Configuration.for('elasticsearch') {
  es_host ''
  port ''
  user 'elastic'
  password 'sdfsfsdfds'
  cloud_id 'ElasticCertifiedEngineer:asdadasd'
  index_name '123_scraper'
  es_source 'elastic_cloud'
}

Configuration.for('general') {
  es_source 'elastic_cloud'
  use_heroku false
  use_app_search false
}

Configuration.for('app_search') {
  host_identifier ''
  api_key ''
  engine_name ''
}

Configuration.for('storage') {
  region 'ap-southeast-1'
  aws_key 'sdfsdfsdfsfsdf'
  aws_secret_key 'sfsdfsdfsdfsdfs+khy8Uqinn95z4w4'
  bucket_name 'jnny-fashion-cache'
}