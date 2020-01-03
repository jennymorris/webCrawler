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
        scraped_data[:price]["regPrice"] = browser.span(class: ['price-value']).text
      end

      #Get description
      browser.button(class: ['js-open-more-details']).click
      sleep(rand(1..2))
      desc = browser.div(class: ['pdp-drawer-content','pdp-details-content'])
      scraped_data[:description] = desc.text
      browser.span(class: ['icon-close-black']).click


      #Get Rating
      # review = browser.span(itemprop: "ratingValue").exists? ? browser.span(itemprop: "ratingValue").text.to_f : 0.0
      # scraped_data[:review] = review

      #Get Size

      colors = browser.div(class: ['product-colors']).links
      colors.each do |color|
        color.click
          sleep(rand(2..3))
        _color = {
          :color_name => color.title,
          :image => color.img.src,
          :size => {}
        }

        browser.button(class: ['picker-trigger','js-picker-trigger']).click
        browser.ul(class: ['picker-list','js-active-list']).lis.each do |_li|

          size = _li.spans.first.text
          stock = true
          if _li.spans.count > 1
            stock = false if _li.spans.last.text == 'Notify me'
          end
          _color[:size][_li.text] =  stock
        end
        scraped_data[:color].push(_color)
      end

      #check if
      url_content = url['content'].nil? ? {} : JSON.parse(url['content'])
  
      if scraped_data != url_content
        self.db_client.update_scrape_url_status(url["id"], 1 , scraped_data.to_json)
        es_client.index_data([scraped_data])
      end
      sleep(rand(1..2))
    rescue Exception => e
      puts e.message
    end
  end

end