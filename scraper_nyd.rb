require 'webdrivers'
require 'watir'
require 'pry'
# require 'sqlite3'
require 'configuration'



$:.unshift File.join(File.dirname(__FILE__))

require 'lib/es_client'
require 'lib/app_search_client'
require 'lib/nyd/process_scrape'
require 'lib/db/pg_client'
require 'lib/storage/storage_client'


if `ps -C 'scraper_nyd.rb' | wc -l`.to_i > 2
  puts 'another process already running'
  exit
end

begin
  Configuration.path = File.join(File.dirname(__FILE__), 'config')
  Configuration.load 'config'
  general_config = Configuration.for('general')
rescue Exception => e
  general_config = nil
end


use_heroku = general_config.use_heroku rescue true

if use_heroku
  use_app_search = ENV['USE_APP_SEARCH'] rescue false

  if use_app_search
    es_client = AppSearchClient.new()
  else
    es_client = EsClient.new()
  end

  db = PgClient.new()
  storage = StorageClient.new()
else
  use_app_search =  general_config.use_app_search rescue false

  if use_app_search
    es_client_config = Configuration.for('app_search')
    es_client = AppSearchClient.new(es_client_config)
  else
    es_client_config = Configuration.for('elasticsearch')
    es_client = EsClient.new(es_client_config)
  end
  db_config         = Configuration.for('database')  
  db = PgClient.new(db_config)

  #storage class instantiate
  storage_config = Configuration.for('storage')
  storage = StorageClient.new(storage_config)
end


# db = SQLite3::Database.open 'nyd.db'
# db.execute "CREATE TABLE IF NOT EXISTS urls(id INTEGER PRIMARY KEY, url TEXT UNIQUE, content TEXT, parent_id INTEGER, scraped INTEGER)"

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--disable-infobars')
options.add_argument('--headless')
user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.50 Safari/537.36'
options.add_argument('--user-agent=' + user_agent)
options.add_argument('--disable-gpu')
options.add_argument('--remote-debugging-port=9222')

browser = Watir::Browser.new(:chrome, options: options)
scraper = ProcessScrape.new(browser, db, es_client,storage)

blacklist_keyword = ['sleepwear', 'lingerie', 'swimwear', 'uncommon-sense', 'belts', 'tights-socks', 'beauty']
url = "https://www.nyandcompany.com/sitemap/"

parent_urls = db.get_all_parents(1).to_a

if parent_urls.empty?
  browser.goto(url)
  parent_urls = browser.div(class: ['row', 'twocol', 'sitemap']).links.map {|x| x.href}.uniq
  
  parent_urls.each do |url|
    begin
      db.insert_url(url,1)
    rescue Exception => e
      puts e.message
    end
  end
  parent_urls = db.get_all_parents(1).to_a
end

parent_urls.each do |parent_url|

  # binding.pry if parent_url == 'https://www.nyandcompany.com/brands-we-love/uncommon-sense/swimwear/N-3177235517/'
  skip = false
  blacklist_keyword.each do |keyword|
    skip = parent_url["url"].match?(keyword)
    if skip
      begin
        db.update_scrape_url_status(parent_url["id"], -1)
      rescue Exception => e 
        puts e.message
      end
      break
    end
  end

  next if skip

  browser.goto(parent_url["url"])

  start_url = db.get_child_urls(parent_url["id"]).to_a

  begin
    if start_url.empty?
      start_url = browser.li(class: ['product','col-3']).links.first.href
      scraper.start_url = start_url.split('?').first
    else 
      scraper.start_url = start_url.first["url"]
      start_url = start_url.first["url"]
    end
  rescue => exception
    next
  end


  
  puts parent_url

  loop do
    all_data = []
    begin
      all_data = scraper.run_scrape(start_url, parent_url["id"])
    rescue Exception => e
      scraper.next_url = nil
    end

    start_url = scraper.next_url
    break if start_url.nil?
    sleep(2)
  end
  db.update_scrape_url_status(parent_url["id"],1)
end

db.reset_all_urls
