require 'nbe/dataset/client'
require 'nbe/dataset/computed_migration'

module NBE
  class DatasetMigrator
    # The migration class takes care of copying a dataset
    # It can copy across environments, copying over referenced regions if needed
    # TODO: once computation strategy (including source column field name)
    # is available from a public api, move to a more sane method of creating columns

    attr_reader :source_id, :target_id

    def initialize(options)
      @source_client = options[:source_client]
      @source_client ||= Dataset::Client.new(
        options[:source_domain],
        options[:source_token],
        options[:user],
        options[:password]
      )
      @target_client = options[:target_client]
      @target_client ||= Dataset::Client.new(
        options[:target_domain],
        options[:target_token],
        options[:user],
        options[:password]
      )
      @source_id = options[:source_id]
      @soda_fountain_ip = options[:soda_fountain_ip]
      @datasync_jar = options[:datasync_jar]
      @row_limit = options[:row_limit]
      @publish_dataset = options[:publish].nil? ? true : options[:publish]
      @ignore_computed_columns = options[:ignore_computed_columns]
      @region_map = {}
    end

    # runs the migrations
    # returns the new dataset 4x4
    def run
      check_for_nbe_or_fail

      create_dataset_on_target
      create_standard_columns
      unless @ignore_computed_columns
        migrate_regions unless @source_client.domain == @target_client.domain
        create_computed_columns
      end
      migrate_data
      publish if @publish_dataset

      puts "#{@target_client.domain}/d/#{target_id}"
      @target_id
    end

    private

    ## Migration Steps

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
      standard_columns.sort { |a, b| a['position'] <=> b['position'] }.each do |col|
        puts "Create column: #{col['name']}"
        @target_client.add_column(@target_id, col)
      end
    end

    def migrate_regions
      puts "Migrating #{source_regions.count} regions to target domain"
      source_regions.each do |old_region|
        puts "Migrating region dataset #{old_region} to target domain."
        new_region = DatasetMigrator.new(
          source_client: @source_client,
          target_client: @target_client,
          ignore_computed_columns: true,
          source_id: old_region,
          publish: true
        ).run
        @region_map[old_region] = new_region
        puts "Finished migrating. #{old_region} => #{new_region}"
      end
    end

    def create_computed_columns
      computed_migration = Dataset::ComputedMigration.new(@region_map, @soda_fountain_ip, @source_id)
      puts "Creating #{computed_migration.transformed_columns.count} computed columns"
      computed_migration.transformed_columns.each do |col|
        puts "Create computed column: #{col['name']}"
        @target_client.add_column(@target_id, col)
      end
    end

    DEFAULT_CHUNK_SIZE = 50_000
    # migrates over up to row_limit rows
    def migrate_data
      puts "Migrating #{@row_limit.nil? ? 'all' : @row_limit} rows into new dataset."
      offset = 0
      limit = DEFAULT_CHUNK_SIZE
      loop do
        limit = [DEFAULT_CHUNK_SIZE, @row_limit - offset].min unless @row_limit.nil?
        rows = @source_client.get_data(@source_id, '$limit' => limit, '$offset' => offset)
        response = @target_client.ingress_data(@target_id, rows)
        offset += response['Rows Created']
        puts "Migrated #{offset} rows to new dataset."
        break if rows.count != limit # all rows have been migrated
        break if @row_limit && offset >= @row_limit # row limit has been reached
      end
    end

    def publish
      puts 'Publishing dataset.'
      @target_client.publish_dataset(@target_id)
    end

    ## Helper Methods

    def dataset_metadata
      @metadata ||= @source_client.get_dataset_metadata(@source_id)
    end

    def v1_metadata
      @v1_metadata ||= @source_client.get_v1_metadata(@source_id)
    end

    def standard_columns
      @standard ||= dataset_metadata['columns'].reject do |col|
        col['fieldName'].start_with?(':')
      end
    end

    def computed_columns
      @computed ||= dataset_metadata['columns'].select do |col|
        col['fieldName'].start_with?(':@')
      end
    end

    def source_regions
      v1_metadata['columns'].select { |key, _| key.start_with?(':@') }.map do |_, value|
        value['computationStrategy']['parameters']['region'].sub('_', '')
      end.uniq
    end
  end # DatasetMigrator
end # NBE
