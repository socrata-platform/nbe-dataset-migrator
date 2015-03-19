require_relative 'lib/client'

begin = {
  "id": "wniu-uvhw",
  "field_name": ":@counties3",
  "name": "counties3",
  "description": "counties3",
  "datatype": "number",
  "computation_strategy": {
    "strategy_type": "georegion",
    "recompute": true,
    "source_columns": [
      "mckb-vz3b"
    ],
    "parameters": {
      "region": "_nmuc-gpu5"
    }
  }
}

end = {
  'name' => 'Not Counties',
  'dataTypeName' => 'number',
  'fieldName' => ':@location_1_point_computed',
  'computationStrategy' => {
    'type' => 'georegion_match_on_point',
    'recompute' => true,
    'source_columns' => [ 'location_1_point' ],
    'parameters' => {
      'region' => "_#{ZIP_CODE_ID}"
    }
  }
}


core_metadata = JSON.parse(File.read('core_metadata.json'))
puts JSON.pretty_generate(core_metadata)

field_names = {}
core_metadata.each do |k,v|
  field_names[v['id']] = k
end
puts JSON.pretty_generate(field_names)

result = core_metadata.select do |k,v|
  k.start_with?(':@')
end

# result.each{ |r| puts JSON.pretty_generate(r) }
result.each do |k,v|
  key = v['computation_strategy']['source_columns'].first
  v['computation_strategy']['source_columns'] = [ field_names[key] ]
end

puts JSON.pretty_generate(result)
