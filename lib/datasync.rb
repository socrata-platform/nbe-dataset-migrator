require 'open3'

module Datasync
  class << self
    def generate_config_file(options)
      config = {
        "domain": options[:target_domain],
        "username": options[:username],
        "password": options[:password],
        "appToken": options[:source_token],
        "portDestinationDomainAppToken": options[:target_token],
        "adminEmail": "",
        "emailUponError": "false",
        "logDatasetID": "",
        "outgoingMailServer": "",
        "smtpPort": "",
        "sslPort": "",
        "smtpUsername": "",
        "smtpPassword": "",
        "filesizeChunkingCutoffMB": "10",
        "numRowsPerChunk": "10000",
        "useNewBackend": true
      }.to_json

      File.write("tmp/config.json", config)
    end

    def run_datasync(options, id)
      datasync_jar = 'resources/DataSync-1.5.4-nbe-capable.jar'

      fail('Cannot find DataSync jar!') unless File.exist?(datasync_jar)

      cmd = "java -jar #{datasync_jar}"
      cmd += ' -t PortJob'
      cmd += " -c tmp/config.json"
      cmd += ' -pm copy_all'
      cmd += " -pd1 #{options[:source_domain]}"
      cmd += " -pi1 #{id}"
      cmd += " -pd2 #{options[:target_domain]}"
      cmd += " -pp true"

      puts 'Executing datasync port job.'
      puts "Source: #{options[:source_domain]}, #{id}"
      puts "Target: #{options[:target_domain]}"

      stdout, stderr, status = Open3.capture3(cmd)

      puts stdout
      puts stderr

      fail('Datasync failed!') unless status

      stdout_parsed = /Your newly created dataset is at:\n#{options[:target_domain]}\/d\/(....-....)/.match(stdout)
      stdout_parsed[1]
    end
  end
end
