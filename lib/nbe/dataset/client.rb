require 'addressable/uri'
require 'httparty'

module NBE
  module Dataset
    class Client
      #TODO: should we add nbe=true query param to all requests?

      include HTTParty

      # debug_output $stdout

      attr_accessor :domain, :app_token, :user, :password

      def initialize(domain, app_token, user, password)
        domain = "https://#{domain}" unless domain.start_with?('http')
        @domain = domain
        @app_token = app_token
        @user = user
        @password = password

        @request_options = {
          headers: {
            'X-App-Token' => @app_token,
            'Content-Type' => 'application/json'
          },
          basic_auth: {
            username: @user,
            password: @password
          }
        }
      end

      def base_options
        @request_options
      end

      def get_data(id, query = {})
        path = "resource/#{id}.json"
        perform_get(path, query: query)
      end

      def ingress_data(id, data)
        path = "api/resource/#{id}"
        perform_post(path, body: data.to_json)
      end

      def get_dataset_metadata(id)
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
        puts "Error accessing #{URI.join(domain, path)}"
        puts response
        fail("Response code: #{response.code}")
      end
    end
  end
end