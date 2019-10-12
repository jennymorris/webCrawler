require 'elastic-app-search'

class AppSearchClient

  attr_accessor :client, :engine_name
  def initialize(config = nil)

    if config.nil?
      self.client = Elastic::AppSearch::Client.new(:host_identifier => ENV['APP_SEARCH_HOST'], :api_key => ENV['APP_SEARCH_API_KEY'])
      self.engine_name = ENV['APP_SEARCH_ENGINE_NAME']
    else
      self.client = Elastic::AppSearch::Client.new(:host_identifier => config.host_identifier, :api_key => config.api_key)
      self.engine_name = config.engine_name
    end
  end

   def rebuild_data_for_indexing(data)
    constructed_data = []

    data.each do |datum|  
      data_structure = {}
      data_structure[:url]          = datum[:url]
      data_structure[:review]       = datum[:review]
      data_structure[:category]     = datum[:category]
      data_structure[:description]  = datum[:description]
      

      if !datum[:size].nil?
        data_structure[:price]        = datum[:price]
        datum[:size].each do |size|
          data_structure[:size] = size[:size_name]

          size[:color_list].each do |color, image|
            next if color == ''
            data_structure[:color] = color
            data_structure[:image] = image
            data_structure[:id] = datum[:url]+size[:size_name]+color
            
            constructed_data.push(data_structure.dup)
          end
        end
      elsif !datum[:color].nil?
        data_structure[:price]        = {"regPrice" => datum[:price]}
        datum[:color].each do |color| 
          data_structure[:color] = color[:color_name]
          data_structure[:image] = color[:image]

          color[:size].each do |key, value| 
            data_structure[:size] = key
            data_structure[:id] = datum[:url]+key+color[:color_name]

            constructed_data.push(data_structure.dup)
          end
        end
      end
    end
    constructed_data
  end

  def index_data(data)
    data =  self.rebuild_data_for_indexing(data)
    self.client.index_documents(self.engine_name, data)
  end

end