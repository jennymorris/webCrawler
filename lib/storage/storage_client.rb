require 'aws-sdk'
require 'aws-sdk-s3'
class StorageClient

  attr_accessor :client, :bucket, :endpoint

  def initialize(config = nil)

    if config.nil?
      Aws.config.update({
        region: ENV['S3_REGION'],
        credentials: Aws::Credentials.new(ENV['AWS_KEY'], ENV['AWS_SECRET_KEY'])
      })
      self.bucket = ENV['S3_BUCKET_NAME']
    else
      Aws.config.update({
        region: config.region,
        credentials: Aws::Credentials.new(config.aws_key, config.aws_secret_key)
      })
      self.bucket = config.bucket_name
    end

    self.client = Aws::S3::Resource.new
  end

  def upload_object(filename, filepath, source = 'Other')
    obj = self.client.bucket(self.bucket).object(source + "/" + filename)
    obj.upload_file(filepath)
    obj.presigned_url(:get, expires_in: 604800)
  end

end