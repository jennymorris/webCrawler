Configuration.for('database') {
  database_name ''
  database_user ''
  database_password ''
  database_host ''
}

Configuration.for('elasticsearch') {
  es_host ''
  port ''
  user ''
  password ''
  cloud_id ''
  index_name ''
}

Configuration.for('general') {
  es_source ''
  use_heroku false
  use_app_search true
}

Configuration.for('app_search') {
  host_identifier ''
  api_key ''
  engine_name ''
}