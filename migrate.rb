require_relative 'lib/client'
require_relative 'lib/computed_migration'
require 'optparse'
require 'pry'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby migrate.rb [options]'

  opts.on('-d', '--dataset [DATASET_ID]', 'Dataset to migrate to target environment.') do |id|
    options[:source_dataset] = id
  end

  opts.on('--sd [DOMAIN]', 'Source domain') do |domain|
    domain = "https://#{domain}" unless domain.start_with?('http')
    options[:source_domain] = domain
  end

  opts.on('--st [TOKEN]', 'Source app token') do |token|
    options[:source_token] = token
  end

  opts.on('--td [DOMAIN]', 'Target domain') do |domain|
    domain = "https://#{domain}" unless domain.start_with?('http')
    options[:target_domain] = domain
  end

  opts.on('--tt [TOKEN]', 'Target app token') do |token|
    options[:target_token] = token
  end

  opts.on('--sf [SODA_FOUNTAIN_IP]', 'IP Address for Soda Fountain (requires VPN)') do |ip|
    options[:sf_ip] = ip
  end

  opts.on('-r', '--rows [ROW_LIMIT]', 'Total number of rows to copy over') do |rows|
    options[:row_limit] = rows.to_i
  end

  opts.on('-a', '--copy-all', 'Flag to copy dataset') do
    options[:row_limit] = false
  end

  opts.on('-h', '--help', 'Displays help') do
    puts(opts)
    exit
  end

end.parse!

options[:username] = ENV['SOCRATA_USER']
fail('No username found in $SOCRATA_USER') if options[:username].nil?
options[:password] = ENV['SOCRATA_PASSWORD']
fail('No password found in $SOCRATA_PASSWORD') if options[:password].nil?

source_client = Client.new(options[:source_domain], app_token: options[:source_token])
target_client = Client.new(options[:target_domain],
                            app_token: options[:target_token],
                            username: options[:username],
                            password: options[:password]
                            )

puts "Fetching dataset info from #{options[:source_domain]}, id: #{options[:source_dataset]}"
source_dataset = source_client.get_schema(options[:source_dataset])

create_dataset = source_dataset.select do |k,_|
  ['name', 'description'].include? (k)
end

puts "Creating dataset: #{create_dataset['name']}"
dataset = target_client.create_dataset(create_dataset)
puts "#{options[:target_domain]}/d/#{dataset['id']}"

# Parse columns into seperate arrays for computed and standard columns
computed, standard = source_dataset['columns'].partition do |col|
  col['fieldName'].start_with?(':')
end

puts "Creating #{standard.count} standard columns:"
standard.each do |col|
  puts "Create column #{col['name']}"
  response = target_client.add_column(dataset['id'], col)
end

computed_migration = ComputedMigration.new(options[:sf_ip], options[:source_dataset])
puts "Migrating #{computed_migration.referenced_datasets.count} curated regions:"
computed_migration.migrate_regions(options)

puts "Creating #{computed_migration.computed_columns.count} computed columns:"
computed_migration.transformed_columns.each do |col|
  if computed.select{ |e| e['fieldName'] == col['fieldName'] }.empty?
    puts "Skipping column #{col} because it isn't in the list of columns from /api/view"
    next
  end
  puts "Create computed column #{col['name']}"
  target_client.add_column(dataset['id'], col)
end

puts "Migrate data from #{options[:source_domain]}, id: #{options[:source_dataset]}"
puts "  to #{options[:target_domain]}, id: #{dataset['id']}"
# TODO: this will be a fuzzy limit for now
row_limit = options[:row_limit]
chunk_size = 10000
total = 0
loop do
  rows = source_client.get_data(options[:source_dataset], '$limit' => chunk_size, '$offset' => total)
  response = target_client.ingress_data(dataset['id'], rows)
  total += response['Rows Created']
  puts "Migrated #{total} rows to new dataset."
  break unless rows.count == chunk_size
  break if row_limit and total >= row_limit
end

puts 'Publishing dataset.'
response = target_client.publish_dataset(dataset['id'])
puts "#{options[:target_domain]}/d/#{dataset['id']}"
