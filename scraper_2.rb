require 'webdrivers'
require 'watir'
require 'pry'
require 'sqlite3'



$:.unshift File.join(File.dirname(__FILE__))

require 'lib/es_client'
require 'lib/app_search_client'
require 'lib/forever_21/process_scrape'

es_client = EsClient.new()
app_search_client = AppSearchClient.new()

db = SQLite3::Database.open 'forever_21.db'
db.execute "CREATE TABLE IF NOT EXISTS urls(id INTEGER PRIMARY KEY, url TEXT UNIQUE, content TEXT, parent_id INTEGER, scraped INTEGER)"

# browser = Watir::Browser.new(:chrome, headless:false)
# scraper = ProcessScrape.new(browser)

options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--disable-infobars')
# options.add_argument('--headless')
user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.50 Safari/537.36'
options.add_argument('--user-agent=' + user_agent)
options.add_argument('--disable-gpu')
options.add_argument('--remote-debugging-port=9222')

browser = Watir::Browser.new(:chrome, options: options)
scraper = ProcessScrape.new(browser)

blacklist_keyword = ['sleepwear', 'lingerie', 'swimwear', 'uncommon-sense', 'belts', 'tights-socks', 'beauty']
url = "https://www.forever21.com/us/shop/info/sitemap"
# browser = Watir::Browser.new


#check if there's unscraped parent_url
parent_urls = db.execute("select url FROM urls WHERE parent_id IS NULL AND scraped = 0")

if parent_urls.empty?
  browser.goto(url)
  browser.span(class: ['glClose']).click rescue nil
  
  all_links = browser.links.select{|x| x.href.match?('https://www.forever21.com/us/shop/catalog/category/f21') && !x.href.match?('main') }
  parent_urls = all_links.map {|x| x.href}.uniq
  #save parent url to db
  
  parent_urls.each do |url|
    begin
      db.execute("INSERT INTO urls (url, scraped) VALUES (?,?)", [url, 0])
    rescue Exception => e
      puts e.message
    end
  end
  parent_urls = db.execute("SELECT id, url FROM urls WHERE parent_id IS NULL AND scraped = 0")
end

change_to_usd = true
parent_urls.each do |parent_url|

  browser.goto parent_url[1]
  browser.span(class: ['glClose']).click rescue nil
  if change_to_usd
    browser.driver.manage.window.maximize
    browser.div(class: ["vm","hide_tablecell_mobile","show_tablecell_tablet","hover_p"]).click
    browser.select(id: "gle_selectedCurrency").options.find {|z| z.value == 'USD'}.click
    browser.input(class: ['glCancelBtn','ae-button']).click
    change_to_usd = false
  end
  children_urls = db.execute("SELECT id,url FROM urls WHERE parent_id = ? AND scraped = 0 LIMIT 3", [parent_url.first])

  if children_urls.empty?
    children_urls = browser.div(id: 'products').links
    children_urls = children_urls.map{|x| x.href}
    children_urls = children_urls.select{|x| x.match?('https://www.forever21.com/us/shop/catalog/product/f21') && !x.match?('main') }

    children_urls.each do |child_url|
      begin
        db.execute("INSERT INTO urls (url, parent_id, scraped) VALUES (?,?,?)", [child_url, parent_url.first, 0])
      rescue Exception => e
        puts e.message
      end
    end
    children_urls = db.execute("SELECT id, url FROM urls WHERE parent_id = ? AND scraped = 0 LIMIT 3", [parent_url.first])
  end

  children_urls.each do |child_url|
    scraper.run_scrape(child_url.last)
    db.execute("UPDATE urls set scraped = scraped + 1 WHERE id = ?", child_url.first)
  end
  
  # es_client.index_data(scraper.all_data)
  app_search_client.index_data(scraper.all_data)
  
  # skip = false
  # blacklist_keyword.each do |keyword|
  #   skip = parent_url.match?(keyword)
  #   break if skip
  # end

  

  # next if skip

  # browser.goto(parent_url)
  # start_url = browser.li(class: ['product','col-3']).links.first.href
  # scraper.start_url = start_url.split('?').first
  
  # puts parent_url

  # loop do
  #   all_data = []
  #   all_data = scraper.run_scrape(start_url)
  #   es_client.index_data(all_data) unless all_data.empty?
  #   start_url = scraper.next_url
  #   break if start_url.nil?
  #   sleep(60)
  # end
  # all_data = scraper.run_scrape(parent_url)

  # es_client.index_data(all_data)
  # sleep(60)
end