require_relative 'lib/client.rb'
require 'pry'

USERNAME = 'michael.brown@socrata.com'
PASSWORD = ENV['SOCRATA_PASSWORD']
STAGING_APP_TOKEN = 'o05aNTU5gxD16SqAbcSFK7PQ1'
PRODUCTION_APP_TOKEN = 'KpoBvruJj9xiIaepXdOgReWCl'
SOURCE_DOMAIN = 'dataspace.demo.socrata.com' # 'opendata-demo.test-socrata.com'
TARGET_DOMAIN = 'michael.test-socrata.com'

CHICAGO_CRIMES = '52my-2pak'
RAIL_EQUIPMENT = 'qfph-stuu'

SOURCE_DATASET = RAIL_EQUIPMENT

source_client = Client.new(SOURCE_DOMAIN, app_token: PRODUCTION_APP_TOKEN)
target_client = Client.new(TARGET_DOMAIN, username: USERNAME, password: PASSWORD, app_token: STAGING_APP_TOKEN)

puts "Fetching schema info from #{SOURCE_DOMAIN}, id: #{SOURCE_DATASET}"
schema = source_client.get_schema(SOURCE_DATASET)

create_schema = schema.select do |k,_|
  ['name', 'description'].include? (k)
end

# create_schema = { 'description': 'test description' }.merge(create_schema)

puts 'Creating dataset'
dataset = target_client.create_dataset(create_schema)
puts "https://#{TARGET_DOMAIN}/d/#{dataset['id']}"

# Add columns
computed, normal = schema['columns'].partition do |col|
  col['fieldName'].start_with?(':')
end

normal.each do |col|
  puts "Create column #{col['name']}"
  response = target_client.add_column(dataset['id'], col)
end

puts 'computed:'
puts JSON.pretty_generate(computed)

puts 'creating computed column for zip codes'
ZIP_CODE_ID = '6nbi-svx4'
response = target_client.add_column(dataset['id'],
  'name' => 'Not Counties',
  'dataTypeName' => 'number',
  'fieldName' => ':@location_1_point_computed',
  'computationStrategy' => {
    'type' => 'georegion_match_on_point',
    'recompute' => true,
    'source_columns' => [ 'location_1_point' ],
    'parameters' => {
      'region' => "_#{ZIP_CODE_ID}"
    }
  }
)
puts response
# pry.break

# '{ "name":"Ward ID", "dataTypeName": "text", "fieldName": ":ward_id", "computationStrategy": { "type": "georegion", "recompute": true, "source_columns": ["location"], "parameters": { "region":"_'$SHP_FOURBYFOUR'" } } }'

puts "Fetching data from #{SOURCE_DOMAIN}, id: #{SOURCE_DATASET}"
rows = source_client.get_data(SOURCE_DATASET)
puts rows[0]

puts "Start ingress"
response = target_client.ingress_data(dataset['id'], rows)
puts response


puts 'publishing dataset'
response = target_client.publish_dataset(dataset['id'])
puts response

#
# puts "poking phiddipides"
# puts target_client.poke_phid(dataset['id'])
