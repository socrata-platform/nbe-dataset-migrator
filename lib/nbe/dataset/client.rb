require 'addressable/uri'
require 'httparty'
require 'json'

module NBE
  module Dataset
    class Client
      include HTTParty
      default_timeout(60 * 5) # set timeout to 5 min
      # debug_output($stdout) # uncomment for debug HTTParty output

      attr_accessor :domain, :app_token, :user, :password
      attr_reader :base_options

      def initialize(domain, app_token, user, password)
        domain = "https://#{domain}" unless domain.start_with?('http')
        @domain = domain
        @app_token = app_token
        @user = user
        @password = password

        @base_options = {
          headers: {
            'X-App-Token' => @app_token,
            'Content-Type' => 'application/json'
          },
          basic_auth: {
            username: @user,
            password: @password
          }
        }
        @base_options[:verify] = false if domain.include?('localhost')
      end

      def get_migration(id)
        path = "api/migrations/#{id}"
        perform_get(path)
      end

      def get_data(id, query = {})
        path = "resource/#{id}.json"
        perform_get(path, query: query)
      end

      def ingress_data(id, data)
        path = "resource/#{id}"
        perform_post(path, body: data.to_json)
      end

      def get_dataset_metadata(id)
        path = "api/views/#{id}.json"
        perform_get(path)
      end

      def get_v1_metadata(id)
        path = "metadata/v1/dataset/#{id}.json"
        perform_get(path)
      end

      def create_dataset(id)
        path = 'api/views'
        perform_post(path, body: id.to_json)
      end

      def publish_dataset(id)
        path = "api/views/#{id}/publication.json"
        perform_post(path)
      end

      def add_column(id, column)
        path = "api/views/#{id}/columns"
        perform_post(path, body: column.to_json)
      end

      private

      def perform_get(path, options = {})
        uri = URI.join(domain, path)
        response = self.class.get(uri, base_options.merge(options))
        handle_error(path, response) unless response.code == 200
        JSON.parse(response.body)
      end

      def perform_post(path, options = {})
        uri = URI.join(domain, path)
        options = base_options.merge(options.merge(query: { nbe: true }))
        response = self.class.post(uri, options)
        handle_error(path, response, options) unless response.code == 200
        JSON.parse(response.body)
      end

      def handle_error(path, response, options = nil)
        warn "Error accessing #{URI.join(domain, path)}"
        warn response
        warn options.delete('body').delete('basic_auth') if options
        fail("Response code: #{response.code}")
      end
    end
  end
end
