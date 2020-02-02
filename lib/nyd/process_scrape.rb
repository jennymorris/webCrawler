require 'open-uri'
require 'digest'

class ProcessScrape

  attr_accessor :browser, :start_url, :next_url, :db_client, :es_client, :storage_client

  def initialize(browser, db_client, es_client, storage_client)
    self.browser = browser
    self.next_url = nil
    self.db_client = db_client
    self.es_client = es_client
    self.storage_client = storage_client
  end

  def run_scrape(url, parent_id)
    all_data = []

    browser.goto(url)
    [*0..2].each do |x|
      begin
        #check if the url is already scraped before
        normalize_url = browser.url.split("?").first

        url_info = self.db_client.url_exist?(normalize_url)
        content_url = {}
  
        if !url_info.empty?
          if url_info.first['scraped'].to_i == 0
            content_url = url_info.first['content'].nil? ? {} : JSON.parse(url_info.first['content'])
          else
            puts "#{url} already scraped before"
            browser.li(class: "next").click
            next
          end
        end
        
        scraped_data = {
            :url => [],
            :size => [],
            :price => {},
            :description => "",
            :review => [],
            :category => ""
          }

        scraped_data[:url] = normalize_url
        puts "#{scraped_data[:url]}"
        #Get Category
        scraped_data[:category] = browser.link(class: "back-otherwise").text.gsub("BACK TO", "") rescue ""

        #Get prices
        prices = browser.p(id: 'productPrice').children
        prices.each do |child|
          next unless child.element_class_name == "Span"
          scraped_data[:price][child.attribute_values[:class]] = child.text
        end

        if scraped_data[:price].empty?
          scraped_data[:price]["regprice"] = browser.p(id: 'productPrice').text
        end

        #Get description
        desc = browser.div(class:["content1", "details", "displayBlock"])
        scraped_data[:description] = desc.inner_html

        #Get Rating
        review = browser.span(itemprop: "ratingValue").exists? ? browser.span(itemprop: "ratingValue").text.to_f : 0.0
        scraped_data[:review] = review

        sizes = browser.select(id: "prod_prodsize").options

        sizes[1..-1].each do |size|
          _size = {
            :size_name => '',
            :color_list => {},
            :stock      => 0
          }
          #click options
          size.click
          sleep(rand(1..2))
          _size[:size_name] = size.value

          #Get colors
          colors = browser.div(id: "colorSwatchesTemplate").child
          colors = colors.children.select{|x| x if x.element_class_name == 'Div'}

          colors.each do |color| 
            begin
              color.click
              sleep(rand(1..2))
              #Get Image URL, Download, Upload to S3 and save presigned url for 1 week
              image_uri = browser.execute_script("return document.getElementsByTagName('canvas')[1].view.url;")
              color_name = color.child.title.gsub("Has Been Selected","")
              download = open("https:#{image_uri}")
              filepath = download.to_path
              filename   = Digest::SHA256.hexdigest(normalize_url + "-" + color_name)
              signed_url = self.storage_client.upload_object(filename, filepath, 'NYD')

              _size[:color_list][color_name] = signed_url

              #get item stock
              stock = browser.input(id: 'availabilityType').value == 'available'
              _size[:stock] = stock
            rescue Exception => e
              puts "Can't Get Color, might be undefined structure or #{e.message}"  
            end
          end

          #push the data 
          scraped_data[:size].push(_size)
          scraped_data[:site_source] = 'NYD'
        end
        
        all_data.push(scraped_data)

        #check if
        if scraped_data != content_url
          self.db_client.insert_children_url(parent_id, scraped_data[:url], 1, scraped_data.to_json, 1)
          es_client.index_data([scraped_data])
        end
        
        browser.li(class: "next").click
        sleep(rand(1..2))
      rescue Exception => e
        puts e.message
        browser.refresh
        browser.li(class: "next").click
      end
    end

    self.next_url = browser.url.split('?').first
    if self.next_url == self.start_url
      self.next_url = nil
    end
    return all_data
  end

end