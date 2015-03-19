require_relative 'lib/client.rb'
require_relative 'lib/computed_migration'
require 'pry'

USERNAME = 'michael.brown@socrata.com'
PASSWORD = ENV['SOCRATA_PASSWORD']
STAGING_APP_TOKEN = 'o05aNTU5gxD16SqAbcSFK7PQ1'
PRODUCTION_APP_TOKEN = 'KpoBvruJj9xiIaepXdOgReWCl'
SOURCE_DOMAIN = 'dataspace.demo.socrata.com' # 'opendata-demo.test-socrata.com'
TARGET_DOMAIN = 'opendata-demo.test-socrata.com'
SODA_FOUNTAIN = '10.1.0.68'

# DATASPACE.DEMO.SOCRATA.COM DATASETS
CHICAGO_CRIMES = '52my-2pak'
RAIL_EQUIPMENT = 'qfph-stuu'

SOURCE_DATASET = CHICAGO_CRIMES

source_client = Client.new(SOURCE_DOMAIN, app_token: PRODUCTION_APP_TOKEN)
target_client = Client.new(TARGET_DOMAIN, username: USERNAME, password: PASSWORD, app_token: STAGING_APP_TOKEN)

puts "Fetching schema info from #{SOURCE_DOMAIN}, id: #{SOURCE_DATASET}"
schema = source_client.get_schema(SOURCE_DATASET)

create_schema = schema.select do |k,_|
  ['name', 'description'].include? (k)
end

# create_schema = { 'description': 'test description' }.merge(create_schema)

puts "Creating dataset: #{create_schema['name']}"
dataset = target_client.create_dataset(create_schema)
puts "https://#{TARGET_DOMAIN}/d/#{dataset['id']}"

# Add columns
computed, normal = schema['columns'].partition do |col|
  col['fieldName'].start_with?(':')
end

puts "Create normal columns..."
normal.each do |col|
  puts "Create column #{col['name']}"
  response = target_client.add_column(dataset['id'], col)
end


puts "Migrating curated regions..."
comp_cols = ComputedMigration.new(SODA_FOUNTAIN, SOURCE_DATASET)

options = {}
options[:username] = USERNAME
options[:password] = PASSWORD
options[:target_token] = STAGING_APP_TOKEN
options[:source_token] = PRODUCTION_APP_TOKEN
options[:source_domain] = "https://#{SOURCE_DOMAIN}"
options[:target_domain] = "https://#{TARGET_DOMAIN}"
comp_cols.migrate_regions(options)

puts "Create computed columns..."

comp_cols.computed_columns.each do |k, v|
  transformed = comp_cols.transform_column(v)
  puts JSON.pretty_generate(transformed)
  response = target_client.add_column(dataset['id'], transformed)
  puts response
end

puts "Fetching data from #{SOURCE_DOMAIN}, id: #{SOURCE_DATASET}"
rows = source_client.get_data(SOURCE_DATASET)
puts rows[0]

puts "Start ingress"
response = target_client.ingress_data(dataset['id'], rows)
puts response


puts 'publishing dataset'
response = target_client.publish_dataset(dataset['id'])
puts response
