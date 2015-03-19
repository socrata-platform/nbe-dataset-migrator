require_relative 'lib/column_manager'
require 'json'

SF_IP = '10.1.0.68'
DS_ID = 'qfph-stuu'
options = {}
options[:username] = 'michael.brown@socrata.com'
options[:password] = ENV['SOCRATA_PASSWORD']
options[:target_token] = 'o05aNTU5gxD16SqAbcSFK7PQ1'
options[:source_token] = 'KpoBvruJj9xiIaepXdOgReWCl'
options[:source_domain] = 'https://dataspace.demo.socrata.com' # 'opendata-demo.test-socrata.com'
options[:target_domain] = 'https://michael.test-socrata.com'


c = ComputedMigration.new(SF_IP, DS_ID)

puts JSON.pretty_generate(c.computed_columns)
puts c.referenced_datasets
puts c.migrate_regions(options)
