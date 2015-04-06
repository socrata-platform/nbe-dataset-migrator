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

      def initialize(metadata, region_map)
        @metadata = metadata
        @region_map = region_map
      end

      def computed_columns
        @computed_columns ||= @metadata['columns'].select do |key, _|
          key.start_with?(':@')
        end
      end

      # columns to be created (transformed to be compatible with the public api)
      def transformed_columns
        @transformed_columns ||= computed_columns.map do |key, value|
          transform_column(key, value)
        end
      end

      def transform_column(field_name, source_column)
        new_column = {}

        new_column['fieldName'] = field_name

        to_delete = %w(fred position hideInTable defaultCardType availableCardTypes)
        to_modify = {
          'physicalDatatype' => 'dataTypeName'
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
        new_column['computationStrategy']['recompute'] = true
        source_region_id = new_column['computationStrategy']['parameters']['region'].sub('_', '')
        new_column['computationStrategy']['parameters']['region'] = "_#{@region_map[source_region_id]}"

        puts JSON.pretty_generate(new_column)
        new_column
      end
    end
  end
end
