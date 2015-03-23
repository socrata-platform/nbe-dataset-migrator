require 'open3'

module NBE
  module Dataset

    class Datasync

      def initialize(source_client, target_client, path_to_jar)
        @source = source_client
        @target = target_client
        @datasync_jar = path_to_jar
        fail("Cannot find DataSync jar (#{@datasync_jar})!") unless File.exist?(@datasync_jar)
        fail("Cannot place config file, tmp folder doesn't exist!") unless Dir.exist?('tmp')
        generate_config_file
      end

      def generate_config_file()
        config = {
          "domain": @target.domain,
          "username": @target.user,
          "password": @target.password,
          "appToken": @source.app_token,
          "portDestinationDomainAppToken": @target.app_token,
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

      def run_datasync(id)

        cmd = "java -jar #{@datasync_jar}"
        cmd += ' -t PortJob'
        cmd += " -c tmp/config.json"
        cmd += ' -pm copy_all'
        cmd += " -pd1 #{@source.domain}"
        cmd += " -pi1 #{id}"
        cmd += " -pd2 #{@target.domain}"
        cmd += " -pp true"

        puts 'Executing datasync port job.'
        puts "Source: #{@source.domain}, #{id}"
        puts "Target: #{@target.domain}"

        stdout, stderr, status = Open3.capture3(cmd)

        fail("Datasync failed!\n#{stdout}\n#{stderr}") unless status

        stdout_parsed = /Your newly created dataset is at:\n#{@target.domain}\/d\/(....-....)/.match(stdout)
        new_id = stdout_parsed[1]

        puts "Newly created dataset is #{new_id}"
        new_id
      end
    end

  end
end
