require 'nbe/dataset/client'
require 'nbe/dataset/computed_migration'
require 'logger'
require 'colorize'

module NBE
  class DatasetMigrator
    # The migration class takes care of copying a dataset
    # It can copy across environments, copying over referenced regions if needed
    # TODO: once computation strategy (including source column field name)
    # is available from a public api, move to a more sane method of creating columns

    DEFAULT_CHUNK_SIZE = 50_000

    attr_reader :source_id, :target_id, :log

    def initialize(options)
      @source_id = options[:source_id] || fail('Source dataset ID is required!')
      @row_limit = options[:row_limit]
      @publish_dataset = options[:publish].nil? ? true : options[:publish]
      @ignore_computed_columns = options[:ignore_computed_columns]
      @region_map = {}
      @label_map = {}
      setup_logger(options[:log_level])
      @source_client = options[:source_client] || Dataset::Client.new(
        options[:source_domain],
        options[:source_token],
        options[:user],
        options[:password],
        log
      )
      @target_client = options[:target_client] || Dataset::Client.new(
        options[:target_domain],
        options[:target_token],
        options[:user],
        options[:password],
        log
      )
    end

    # runs the migrations
    # returns self
    def run
      check_for_nbe_or_fail

      create_dataset_on_target
      create_standard_columns
      unless @ignore_computed_columns
        migrate_regions unless @source_client.domain == @target_client.domain
        create_computed_columns
        add_geometry_labels
      end
      migrate_data
      publish if @publish_dataset

      log.info "New dataset: #{@target_client.domain}/d/#{target_id}"
      self
    end

    private

    ## Migration Steps

    def check_for_nbe_or_fail
      log.debug "Verifying that dataset #{source_id} is an NBE dataset."
      return if dataset_metadata['newBackend']
      nbe_id = @source_client.get_migration(source_id)['nbeId']
      log.error("Dataset #{source_id} is on the old backend. Use DataSync for OBE migrations")
      log.error("To copy this dataset using this gem, use the migrated id: #{nbe_id}")
      fail('This gem cannot copy OBE datasets!')
    end

    def create_dataset_on_target
      log.info "Creating dataset: #{dataset_metadata['name']}"
      create_details = dataset_metadata.select do |k, _|
        %w(name description).include?(k)
      end
      created_dataset = @target_client.create_dataset(create_details)
      log.info "Created dataset: #{@target_client.domain}/d/#{created_dataset['id']}"
      @target_id = created_dataset['id']
    end

    def create_standard_columns
      log.info "Creating #{standard_columns.count} standard columns"
      standard_columns.each do |col|
        log.debug "Create column: #{col['name']}"
        @target_client.add_column(@target_id, col)
      end
    end

    def migrate_regions
      log.info "Migrating #{source_regions.count} regions to target domain"
      source_regions.each do |old_region|
        log.info "Migrating region dataset #{old_region} to target domain."
        new_region = DatasetMigrator.new(
          source_client: @source_client,
          target_client: @target_client,
          ignore_computed_columns: true,
          source_id: old_region,
          publish: true,
          log_level: log.level == Logger::INFO ? Logger::WARN : log.level
        ).run.target_id
        old_metadata = @source_client.get_v1_metadata(old_region)
        label = old_metadata['geometryLabel']
        @label_map[new_region] = label unless label.nil?
        @region_map[old_region] = new_region
        log.info "Finished migrating. #{old_region} => #{new_region}"
      end
    end

    def create_computed_columns
      computed_migration = Dataset::ComputedMigration.new(v1_metadata, @region_map)
      log.info "Creating #{computed_migration.transformed_columns.count} computed columns"
      computed_migration.transformed_columns.each do |col|
        log.debug "Create computed column: #{col['name']}"
        @target_client.add_column(@target_id, col)
      end
    end

    # migrates over up to row_limit rows
    def migrate_data
      log.info "Migrating #{@row_limit.nil? ? 'all' : @row_limit} rows into new dataset."
      offset = 0
      limit = DEFAULT_CHUNK_SIZE
      loop do
        limit = [DEFAULT_CHUNK_SIZE, @row_limit - offset].min unless @row_limit.nil?
        break if limit == 0 # row_limit is zeror or all rows have been migrated
        rows = @source_client.get_data(@source_id, '$limit' => limit, '$offset' => offset)
        response = @target_client.ingress_data(@target_id, rows)
        offset += response['Rows Created']
        log.info "Migrated #{offset} rows to new dataset."
        break if rows.count != limit # all rows have been migrated
        break if @row_limit && offset >= @row_limit # row limit has been reached
      end
    end

    def publish
      log.info 'Publishing dataset.'
      @target_client.publish_dataset(@target_id)
    end

    def add_geometry_labels
      return if @label_map.count == 0
      log.info 'Adding geometry labels.'
      @label_map.each do |region, label|
        log.debug "Setting the geometryLabel => #{label} for region #{region}"
        metadata = @target_client.get_v1_metadata(region)
        metadata['geometryLabel'] = label
        @target_client.update_v1_metadata(region, metadata)
      end
    end

    ## Helper Methods

    def setup_logger(log_level)
      @log = Logger.new(STDOUT)
      @log.formatter = proc do |severity, datetime, progname, msg|
        case severity
        when 'DEBUG' then color = :blue
        when 'INFO' then color = :white
        when 'WARN' then color = :yellow
        else color = :light_red
        end
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S.%2N')} [#{@source_id}] #{severity.rjust(5)}: #{msg}\n".send(color)
      end
      @log.level = log_level || Logger::INFO
    end

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
