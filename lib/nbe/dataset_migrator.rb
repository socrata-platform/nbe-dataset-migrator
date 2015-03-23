require 'nbe/dataset/client'
require 'nbe/dataset/computed_migration'
require 'nbe/dataset/datasync'

module NBE
  class DatasetMigrator

    # The migration class takes care of copying a dataset
    # It can copy across environments, copying over referenced regions if necessary

    attr_reader :source_id, :target_id

    def initialize(options)
      @source_client = Dataset::Client.new(options[:source_domain], options[:source_token], options[:user], options[:password])
      @target_client = Dataset::Client.new(options[:target_domain], options[:target_token], options[:user], options[:password])
      @source_id = options[:source_id]
      @soda_fountain_ip = options[:soda_fountain_ip]
      @datasync_jar = options[:datasync_jar]
    end

    def create_dataset_on_target
      puts "Creating dataset: #{dataset_metadata['name']}"
      create_details = dataset_metadata.select do |k, _|
        ['name', 'description'].include?(k)
      end
      created_dataset = @target_client.create_dataset(create_details)
      puts "Created dataset: #{@target_client.domain}/d/#{created_dataset['id']}"
      @target_id = created_dataset['id']
    end

    def create_standard_columns
      puts "Creating #{standard_columns.count} standard columns"
      standard_columns.each do |col|
        puts "Create column: #{col['name']}"
        response = @target_client.add_column(@target_id, col)
      end
    end

    def create_computed_columns(migrate_regions = true)
      computed_migration = Dataset::ComputedMigration.new(@soda_fountain_ip, @source_id)
      if migrate_regions
        puts "Migrating #{computed_migration.referenced_datasets.count} curated regions:"
        computed_migration.migrate_regions(datasync)
      end
      puts "Creating #{computed_migration.transformed_columns.count} computed columns"
      computed_migration.transformed_columns.each do |col|
        puts "Create computed column: #{col['name']}"
        response = @target_client.add_column(@target_id, col)
      end
    end

    DEFAULT_CHUNK_SIZE = 10000
    # migrates over up to row_limit rows
    # TODO: this is a fuzzy limit, guaranteed to be correct within 10000 rows
    def migrate_data(row_limit = nil)
      puts "Migrating up to #{row_limit} rows into new dataset."
      offset = 0
      limit = DEFAULT_CHUNK_SIZE
      loop do
        rows = @source_client.get_data(@source_id, '$limit' => limit, '$offset' => offset)
        response = @target_client.ingress_data(@target_id, rows)
        offset += response['Rows Created']
        puts "Migrated #{offset} rows to new dataset."
        break if rows.count != limit # all rows have been migrated
        break if row_limit && offset >= row_limit # row limit has been reached
      end
    end

    def publish
      puts 'Publishing dataset.'
      @target_client.publish_dataset(@target_id)
    end

    private

    def dataset_metadata
      @metadata ||= @source_client.get_dataset_metadata(@source_id)
    end

    def standard_columns
      @standard ||= dataset_metadata['columns'].select do |col|
        not col['fieldName'].start_with?(':')
      end
    end

    def datasync
      @datasync ||= Dataset::Datasync.new(@source_client, @target_client, @datasync_jar)
    end

    # TODO: once computation strategy (including source column field name)
    # is available from a public api, move to a more sane method of creating columns

  end # DatasetMigrator
end # NBE
