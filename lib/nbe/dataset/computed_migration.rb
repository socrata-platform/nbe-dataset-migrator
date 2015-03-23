require 'httparty'
require 'securerandom'
require 'nbe/dataset/datasync'

module NBE
  module Dataset

    class ComputedMigration

      # The ComputedMigration class helps with migrating computed columns from one environment to another
      # Currently, it uses the Soda Fountain api (requires VPN!) to get metadata about the computed columns
      # TODO: fix this to use the public api: /dataset_metadata/four_by_four.json once changes are pushed to prod

      def initialize(soda_fountain_ip, dataset_id)
        uri = URI.join("http://#{soda_fountain_ip}:6010", "dataset/_#{dataset_id}")
        response = HTTParty.get(uri)
        fail("ERROR: #{response}") unless response.code == 200
        @sf_metadata = JSON.parse(response.body)
        @dataset = dataset_id
      end

      def computed_columns
        @computed_columns ||= @sf_metadata['columns'].select do |k,v|
          k.start_with?(':@')
        end
      end

      # columns to be created (transformed to be compatible with the public api)
      def transformed_columns
        @transformed_columns ||= computed_columns.map do |k, v|
          transformed = transform_column(v)
        end
      end

      # Given a four by four, decide the column name
      def map_column_id(column_id)
        @column_ids_to_name ||= build_column_map
        @column_ids_to_name[column_id]
      end

      def build_column_map
        columns = {}
        @sf_metadata['columns'].each do |k,v|
          columns[v['id']] = k
        end
        columns
      end

      def transform_column(source_column)
        new_column = {}

        delete = ['id']
        modify = {
          'field_name' => 'fieldName',
          'datatype' => 'dataTypeName',
          'computation_strategy' => 'computationStrategy'
        }

        source_column.each do |k,v|
          next if delete.include?(k)

          new_key = modify[k] || k
          new_column[new_key] = v
        end

        strategy_type = new_column['computationStrategy'].delete('strategy_type')
        fail('strategy type not georegion_match_on_point, not sure what to do!') unless strategy_type == 'georegion_match_on_point'
        new_column['computationStrategy']['type'] = 'georegion_match_on_point'
        source_col_id = new_column['computationStrategy']['source_columns'].first
        new_column['computationStrategy']['source_columns'] = [ map_column_id(source_col_id) ]
        source_region_id = new_column['computationStrategy']['parameters']['region'].sub('_', '')
        new_column['computationStrategy']['parameters']['region'] = "_#{map_region_id(source_region_id)}"

        new_column
      end

      # return an array of the curated regions that need to be migrated over
      def referenced_datasets
        @referenced_datasets ||= computed_columns.map do |k,v|
          v['computation_strategy']['parameters']['region'].sub('_','')
        end.uniq
      end

      def map_region_id(id)
        @region_mapping ? @region_mapping[id] : id
      end

      def migrate_regions(datasync)

        @region_mapping = {}
        referenced_datasets.each do |id|
          @region_mapping[id] = datasync.run_datasync(id)
        end
        @region_mapping
      end

    end
  end
end
