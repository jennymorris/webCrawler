class ProcessScrape

  attr_accessor :browser, :start_url, :next_url, :all_data, :url_content

  def initialize(browser)
    self.browser = browser
    self.next_url = nil
    self.all_data = []
  end

  def run_scrape(url)
    scraped_data = {
            :url => [],
            :color => [],
            :price => {},
            :description => "",
            :review => [],
            :category => ""
          }

    browser.goto(url)
    # 'https://www.forever21.com/us/shop/catalog/product/f21/dress/2000388233/01'
    
    scraped_data[:url] = url
    scraped_data[:price] = browser.div(id: 'ItemPrice').span.inner_html
    scraped_data[:review] = browser.p(id: 'ReviewRatingDescription').inner_html.split(' ').first.to_i
    scraped_data[:description] = browser.div(id: "tabDescriptionContent").sections.first.inner_html
    scraped_data[:category] = browser.div(class:["breadcrumb"]).links.last.inner_html rescue nil

    browser.ul(id: 'colorButton').lis.each do |li|
      li.click
      _color = {
            :color_name => '',
            :image => '',
            :size => {}
          }
       _color[:color_name] = browser.p(id: 'selectedColorName').inner_html
       _color[:image] = browser.div(id: 'modelImage_1_front_750').img.src rescue nil

       browser.ul(id: 'sizeButton').lis.each do |_li|
         _color[:size][_li.text] =  _li.span.attributes[:class] !='oos' rescue false
       end
      scraped_data[:color].push(_color)
    end

    self.url_content = scraped_data.to_json
    self.all_data.push(scraped_data)
  end

end