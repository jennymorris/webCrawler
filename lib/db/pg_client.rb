require 'pg'
class PgClient

  attr_accessor :client
  def initialize(config = nil)

    if config.nil?
      self.client = PG.connect ENV['DATABASE_URL']
    else
      self.client = PG.connect :dbname => config.database_name, :user => config.database_user, :password => config.database_password, :host => config.database_host
    end
    
    migration()
  end

  def migration
    self.client.exec "CREATE TABLE IF NOT EXISTS urls(id SERIAL PRIMARY KEY, url TEXT UNIQUE, content TEXT, parent_id INTEGER, scraped INTEGER, source INT)"
  end


  def execute_query(query, params = [])
    return self.client.exec_params(query, params)
  end

  def get_all_parents(source)
    execute_query('select id, url FROM urls WHERE parent_id IS NULL AND scraped = 0 AND source = $1', [source])
  end

  def insert_url(url, source_id)
    execute_query('INSERT INTO urls (url, scraped, source) VALUES ($1, 0, $2)', [url, source_id])
  end

  def update_scrape_url_status(url_id, status, content = nil)
    execute_query('UPDATE urls SET scraped = $1 , content = $3 WHERE id = $2', [status, url_id, content])
  end

  def get_child_urls(parent_url_id)
    execute_query('SELECT * FROM urls where parent_id = $1 AND scraped < 1 ORDER BY ID DESC LIMIT 1', [parent_url_id])
  end

  def get_all_child_urls(parent_url_id)
    execute_query('SELECT * FROM urls where parent_id = $1 AND scraped < 1 ORDER BY ID DESC', [parent_url_id])
  end

  def insert_children_url(parent_id, url, status, content)
    execute_query('INSERT INTO urls (url, parent_id, scraped, content) VALUES ($1,$2, $3, $4)', [url, parent_id, status,content])
  end

  def url_exist?(url)
    result = execute_query('SELECT * FROM urls WHERE url = $1',[url]).to_a

    return result
  end

  def reset_all_urls
    execute_query("UPDATE urls SET scraped = 0 where scraped = 1")
  end 



end