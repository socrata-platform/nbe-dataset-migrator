require 'addressable/uri'
require 'httparty'

class Client
  include HTTParty

  # debug_output $stdout

  attr_accessor :domain, :username, :password, :app_token, :auth, :options

  def initialize(domain, options = {})
    domain = "https://#{domain}" unless domain.start_with?('http')
    @domain = domain
    @request_options = {
      headers: {
        'X-App-Token' => options[:app_token],
        'Content-Type' => 'application/json'
      }
    }
    @request_options[:basic_auth] = {
      username: options[:username],
      password: options[:password]
    } unless options[:username].nil?
  end

  def base_options
    @request_options
  end

  def headers
    @request_options[:headers]
  end

  def get_data(id, query = {})
    path = "resource/#{id}.json"
    perform_get(path, query: query)
  end

  def ingress_data(id, data)
    path = "api/resource/#{id}"
    perform_post(path, body: data.to_json)
  end

  def get_schema(id)
    path = "api/views/#{id}.json"
    perform_get(path)
  end

  def create_dataset(id, nbe = true)
    path = "api/views"
    perform_post(path, body: id.to_json, query: { nbe: true })
  end

  def publish_dataset(id)
    path = "api/views/#{id}/publication.json"
    perform_post(path)
  end

  def add_column(id, column)
    path = "api/views/#{id}/columns"
    perform_post(path, body: column.to_json, query: {nbe: true})
  end

  private

  def perform_get(path, options = {})
    uri = URI.join(domain, path)
    response = self.class.get(uri, options)
    handle_error(path, response) unless response.code == 200
    JSON.parse(response.body)
  end

  def perform_post(path, options = {})
    uri = URI.join(domain, path)
    response = self.class.post(uri, base_options.merge(options))
    handle_error(path, response) unless response.code == 200
    JSON.parse(response.body)
  end

  def handle_error(path, response)
    puts "Error accessing #{path}"
    puts response
    fail("Response code: #{response.code}")
  end
end
