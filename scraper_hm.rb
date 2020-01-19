require 'webdrivers'
require 'watir'
require 'pry'
# require 'sqlite3'
require 'configuration'



$:.unshift File.join(File.dirname(__FILE__))

require 'lib/es_client'
require 'lib/app_search_client'
require 'lib/hm/process_scrape'
require 'lib/db/pg_client'


if `ps -C 'scraper_hm.rb' | wc -l`.to_i > 2
  puts 'another process already running'
  exit
end

def get_all_parent_urls(db, browser)
  blacklist_keyword = []
  url = "http://www.hm.com/us"

  parent_urls = db.get_all_parents(2).to_a

  if parent_urls.empty?
    browser.goto(url)
    parent_urls = browser.ul(class: ['menu__primary']).links.map {|x| x.href}.uniq
    
    parent_urls.each do |url|
      begin
        db.insert_url(url, 2)
      rescue Exception => e
        puts e.message
      end
    end
    parent_urls = db.get_all_parents(2).to_a
  end

  return parent_urls
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
scraper = ProcessScrape.new(browser, db, es_client)

parent_urls = get_all_parent_urls(db, browser)


parent_urls.each do |parent_url|

  skip = false
  blacklist_keyword = []
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

  next unless browser.ul(class: ['products-listing']).present?

  child_urls = db.get_child_urls(parent_url["id"]).to_a

  if child_urls.empty?

    counter = 0
    loop do
      begin
        browser.button(class: ['button','js-load-more']).click
        sleep(5)
        counter += 1

        break if counter == 10 && parent_url['url'].match?('view-all')
      rescue Exception => e
        puts e.message
        break
      end
    end

    child_urls = browser.ul(class: ['products-listing']).links.map{|x|  x.href}.uniq
    

      child_urls.each do |url|
        begin
          db.insert_children_url(parent_url['id'], url, 0, nil)
        rescue
          puts "Child URL Already exist"
        end
      end

    child_urls = db.get_child_urls(parent_url["id"]).to_a
  end

  child_urls.each do |url|
    puts "Scraping #{url}"
   scraper.run_scrape(url, parent_url["id"])
  end

  db.update_scrape_url_status(parent_url["id"],1)

end

db.reset_all_urls

