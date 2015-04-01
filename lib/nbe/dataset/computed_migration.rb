require 'httparty'
require 'securerandom'

module NBE
  module Dataset
    class ComputedMigration
      # The ComputedMigration class helps with migrating computed
      # columns from one environment to another. Currently, it uses
      # the Soda Fountain api (requires VPN!) to get metadata about the
      # computed columns
      # TODO: fix this to use the public api:
      # /dataset_metadata/four_by_four.json once changes are pushed to prod

      def initialize(region_map, soda_fountain_ip, dataset_id)
        uri = URI.join("http://#{soda_fountain_ip}:6010",
                       "dataset/_#{dataset_id}")
        response = HTTParty.get(uri)
        fail("ERROR: #{response}") unless response.code == 200
        @region_map = region_map
        @sf_metadata = JSON.parse(response.body)
        @dataset = dataset_id
      end

      def computed_columns
        @computed_columns ||= @sf_metadata['columns'].select do |key, _|
          key.start_with?(':@')
        end
      end

      # columns to be created (transformed to be compatible with the public api)
      def transformed_columns
        @transformed_columns ||= computed_columns.map do |_, value|
          transform_column(value)
        end
      end

      def transform_column(source_column)
        new_column = {}

        to_delete = ['id']
        to_modify = {
          'field_name' => 'fieldName',
          'datatype' => 'dataTypeName',
          'computation_strategy' => 'computationStrategy'
        }

        source_column.each do |key, value|
          next if to_delete.include?(key)

          new_key = to_modify[key] || key
          new_column[new_key] = value
        end

        strategy_type = new_column['computationStrategy'].delete('strategy_type')
        unless strategy_type == 'georegion_match_on_point'
          fail('strategy type not georegion_match_on_point, not sure what to do!')
        end
        new_column['computationStrategy']['type'] = 'georegion_match_on_point'
        source_region_id = new_column['computationStrategy']['parameters']['region'].sub('_', '')
        new_column['computationStrategy']['parameters']['region'] = "_#{@region_map[source_region_id]}"

        new_column
      end
    end
  end
end
