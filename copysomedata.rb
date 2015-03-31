#!/usr/bin/env ruby

require 'nbe-dataset-migrator'

options = {
  user: 'franklin.williams@socrata.com',
  password: 'REDACTED',
  source_domain: 'https://data.cityofchicago.org',
  source_token: 'UvJap5g1VKRTFcG4wFzEIm7RO',
  target_domain: 'https://localhost:9443',
  target_token: 'eFaEoVVLSCU1u9rdEqAHwuyee',
  soda_fountain_ip: '10.1.0.68',
  source_id: '6zsd-86xi',
  publish: true,
  row_limit: 20_000_000,
  datasync_jar: '/Users/franklinwilliams/Developer/Socrata/nbe-dataset-migrator/resources/DataSync-1.5.4-nbe-capable.jar'
}

migrator = NBE::DatasetMigrator.new(options)
migrator.run
