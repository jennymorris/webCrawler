class ProcessScrape

  attr_accessor :browser, :start_url, :next_url, :db_client, :es_client

  def initialize(browser, db_client,es_client)
    self.browser = browser
    self.next_url = nil
    self.db_client = db_client
    self.es_client = es_client
  end

  def run_scrape(url, parent_id)

    all_data = []

    browser.goto(url["url"])

    begin
      scraped_data = {
          :url => [],
          :color => [],
          :price => {},
          :description => "",
          :review => [],
          :category => ""
        }

      scraped_data[:url] = url["url"]
      puts "#{scraped_data[:url]}"
      #Get Category
      scraped_data[:category] = ""

      #Get prices
      if scraped_data[:price].empty?
        scraped_data[:price]["regprice"] = browser.span(class: ['price-value']).text
      end

      #Get description
      product_title = browser.h1(class: ['primary','product-item-headline']).text
      browser.button(class: ['js-open-more-details']).click
      sleep(rand(1..2))
      desc = browser.div(class: ['pdp-drawer-content','pdp-details-content'])
      scraped_data[:description] = product_title + " " + desc.text
      browser.span(class: ['icon-close-black']).click


      # Get Rating
      begin
        browser.button(class: ['average-customer-rating']).click
        review = browser.div(class: ['star-average-number']).text.to_f rescue 0.0
        browser.refresh
        scraped_data[:review] = review
        sleep(rand(1..2))
      rescue Exception => e 
        puts "Failed get Review"
        scraped_data[:review] = 0.0
      end

      #Get Size

      begin
        colors = browser.div(class: ['product-colors']).links
        colors.each do |color|
          puts "get color"
          color.click
            sleep(rand(2..3))
          _color = {
            :color_name => color.title,
            :image => color.img.src,
            :size => {}
          }
          begin
            puts "click picker"
            browser.button(class: ['picker-trigger','js-picker-trigger']).click
            browser.ul(class: ['picker-list','js-active-list']).lis.each do |_li|
    
              size = _li.spans.first.text
              next if ['select size', 'oos'].include?(size.downcase)
              stock = true
              if _li.spans.count > 1
                stock = false if _li.spans.last.text == 'Notify me'
              end
              _color[:size][_li.text] =  stock
            end
            scraped_data[:color].push(_color)
          rescue Exception => e
            scraped_data[:color].push(_color)
          end
          browser.divs(class: ['picker-option']).first.click
        end
      rescue Exception => e
        puts "Get color failed!!! #{e.message}"
      end

      scraped_data[:site_source] = 'HM'
      #check if
      url_content = url['content'].nil? ? {} : JSON.parse(url['content'])
  
      if scraped_data != url_content
        puts "INDEX DATA"
        result = es_client.index_data([scraped_data])
        if result["errors"]
          self.db_client.update_scrape_url_status(url["id"], -1 , scraped_data.to_json)
        else
          self.db_client.update_scrape_url_status(url["id"], 1 , scraped_data.to_json)
        end
      end
      sleep(rand(1..2))
    rescue Exception => e
      puts "ERROR!"
      puts e.message
    end
  end

end