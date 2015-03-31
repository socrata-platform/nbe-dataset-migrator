require 'nbe/dataset/client'
require 'nbe/dataset/computed_migration'
require 'nbe/dataset/datasync'

module NBE
  class DatasetMigrator
    # The migration class takes care of copying a dataset
    # It can copy across environments, copying over referenced regions if needed
    # TODO: once computation strategy (including source column field name)
    # is available from a public api, move to a more sane method of creating columns

    attr_reader :source_id, :target_id

    def initialize(options)
      @source_client = Dataset::Client.new(
        options[:source_domain],
        options[:source_token],
        options[:user],
        options[:password]
      )
      @target_client = Dataset::Client.new(
        options[:target_domain],
        options[:target_token],
        options[:user],
        options[:password]
      )
      @source_id = options[:source_id]
      @soda_fountain_ip = options[:soda_fountain_ip]
      @datasync_jar = options[:datasync_jar]
      @row_limit = options[:row_limit] || 500_000
      @publish_dataset = options[:publish].nil? ? options[:publish] : true
    end

    # options[:row_limit], default: copy everything
    # options[:publish], default: true
    def run
      check_for_nbe_or_fail

      create_dataset_on_target
      create_standard_columns
#      create_computed_columns unless @datasync_jar.nil?
      migrate_data
      publish if @publish_dataset

      puts "#{@target_client.domain}/d/#{target_id}"
    end

    private

    def check_for_nbe_or_fail
      puts "Verifying that dataset #{source_id} is an NBE dataset."
      return if dataset_metadata['newBackend']
      nbe_id = @source_client.get_migration(source_id)['nbeId']
      warn("Dataset #{source_id} is on the old backend. Use DataSync for OBE migrations")
      warn("To copy this dataset using this gem, use the migrated id: #{nbe_id}")
      fail('This gem cannot copy OBE datasets!')
    end

    def create_dataset_on_target
      puts "Creating dataset: #{dataset_metadata['name']}"
      create_details = dataset_metadata.select do |k, _|
        %w(name description).include?(k)
      end
      created_dataset = @target_client.create_dataset(create_details)
      puts "Created dataset: #{@target_client.domain}/d/#{created_dataset['id']}"
      @target_id = created_dataset['id']
    end

    def create_standard_columns
      puts "Creating #{standard_columns.count} standard columns"
      standard_columns.each do |col|
        puts "Create column: #{col['name']}"
        @target_client.add_column(@target_id, col)
      end
    end

    def create_computed_columns
      computed_migration = Dataset::ComputedMigration.new(@soda_fountain_ip, @source_id)
      migrate_regions = @source_client.domain != @target_client.domain
      if migrate_regions
        puts "Migrating #{computed_migration.referenced_datasets.count} curated regions:"
        computed_migration.migrate_regions(datasync)
      else
        puts 'Skipping region migration, dataset domains are the same.'
      end
      puts "Creating #{computed_migration.transformed_columns.count} computed columns"
      computed_migration.transformed_columns.each do |col|
        puts "Create computed column: #{col['name']}"
        @target_client.add_column(@target_id, col)
      end
    end

    DEFAULT_CHUNK_SIZE = 200_000
    # migrates over up to row_limit rows
    def migrate_data
      puts "Migrating up to #{@row_limit} rows into new dataset."
      offset = 0
      loop do
        limit = [DEFAULT_CHUNK_SIZE, @row_limit - offset].min
        rows = @source_client.get_data(@source_id, '$limit' => limit, '$offset' => offset)
        response = @target_client.ingress_data(@target_id, rows)
        offset += response['Rows Created']
        puts "Migrated #{offset} rows to new dataset."
        break if rows.count != limit # all rows have been migrated
        break if offset >= @row_limit # row limit has been reached
      end
    end

    def publish
      puts 'Publishing dataset.'
      @target_client.publish_dataset(@target_id)
    end

    def dataset_metadata
      @metadata ||= @source_client.get_dataset_metadata(@source_id)
    end

    def standard_columns
      @standard ||= dataset_metadata['columns'].reject do |col|
        col['fieldName'].start_with?(':')
      end
    end

    def datasync
      @datasync ||= Dataset::Datasync.new(
        @source_client,
        @target_client,
        @datasync_jar
      )
    end
  end # DatasetMigrator
end # NBE
