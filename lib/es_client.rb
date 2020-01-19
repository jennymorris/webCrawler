require 'elasticsearch'

class EsClient
  attr_accessor :client, :index_name

  def initialize(config = nil)
    if config.nil?
      es_source = ENV['ES_SOURCE'] rescue 'production'
      self.index_name = ENV['ES_INDEX_NAME']
      case es_source
      when 'production'
        self.client = Elasticsearch::Client.new hosts: [
              { host: ENV['ES_HOST'],
                port: ENV['ES_PORT'],
                user: ENV['ES_USER'],
                password: ENV['ES_PASSWORD']
              }]
      when 'elastic_cloud'
        self.client = Elasticsearch::Client.new hosts: [
              { user: ENV['ES_USER'],
                password: ENV['ES_PASSWORD'],
                cloud_id: ENV['ES_CLOUD_ID']
              }]
      end
    else
      es_source = config.es_source rescue 'local'
      self.index_name = config.index_name
      case es_source
      when 'local'
        self.client = Elasticsearch::Client.new hosts: [
                      { host: config.es_host,
                        port: config.port
                      }]
      when 'production'
        self.client = Elasticsearch::Client.new hosts: [
                      { host: config.es_host,
                        port: config.port,
                        user: config.user,
                        password: config.password
                      }]
      when 'elastic_cloud'
        self.client = Elasticsearch::Client.new hosts: [
              { user: config.user,
                password: config.port,
                cloud_id: config.cloud_id
              }]
      end
    end
    
    get_or_create_index
  end

  def get_or_create_index

    es_mapping = {
      mappings: {
        properties: {
          description: {
            type: "text",
            fields: {
              keyword: {
                type: "keyword",
                ignore_above: 256
              }
            }
          },
          image: {
            type: "text"
          },
          category: {
            type: "text"
          },
          url: {
            type: "text"
          },
          size: {
            type: "text"
          },
          color: {
            type: "text"
          },
          review: {
            type: "byte",
          },
          price: {
            type: "nested"
          },
          stock: {
            type: "boolean"
          }
        }
      }
    }
    
    if (self.client.indices.get(index: self.index_name) rescue nil).nil?
      client.indices.create(index: self.index_name, body: es_mapping)
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

            index = {
              index: {
                _index: self.index_name,
                _type: '_doc',
                _id: datum[:url]+size[:size_name]+color,
                data: data_structure
              }
            }
            constructed_data.push(index.dup)
          end
        end
      elsif !datum[:color].nil?
        data_structure[:price]        = datum[:price]
        datum[:color].each do |color| 
          data_structure[:color] = color[:color_name]
          data_structure[:image] = color[:image]

          color[:size].each do |key, value| 
            data_structure[:size] = key
            index = {
              index: {
                _index: self.index_name,
                _type: '_doc',
                _id: datum[:url]+key+color[:color_name],
                data: data_structure
              }
            }
            constructed_data.push(index.dup)
          end
        end
      end
    end
    constructed_data
  end

  def index_data(data)
    constructed_data = rebuild_data_for_indexing(data)
    client.bulk body:constructed_data
  end
end