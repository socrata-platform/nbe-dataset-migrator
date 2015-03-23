nbe-dataset-migrator
=============================
Migrates NBE datasets between environments

### Overview

This is a script to help with NBE->NBE dataset migrations.
It works loosely following the following steps:
* Fetch dataset metadata from the source environment
* Create dataset with the same name in the target environment
* Create the standard columns in the new dataset
* Find any computed columns in source dataset, and the curated regions the reference
* Migrate over the curated regions to target environment (using DataSync)
* Create the computed columns in the new dataset, referencing the new curated regions
* Copy over data using the SODA2 REST API
* Publish

### Running the script

* Run the script from the repos root directory.
* Uses ruby 2.2.1
* Gets Socrata username & password from environment variables: `$SOCRATA_USER` & `$SOCRATA_PASSWORD`
```
ruby migrate.rb --sd dataspace.demo.socrata.com --st <APP_TOKEN> --td opendata-demo.test-socrata.com --tt <APP_TOKEN> --sf <SODA_FOUNTAIN_IP> -r 50000 -d <DATASET_ID>
```

```
Usage: ruby migrate.rb [options]
    -d, --dataset [DATASET_ID]       Dataset to migrate to target environment.
        --sd [DOMAIN]                Source domain
        --st [TOKEN]                 Source app token
        --td [DOMAIN]                Target domain
        --tt [TOKEN]                 Target app token
        --sf [SODA_FOUNTAIN_IP]      IP Address for Soda Fountain (requires VPN)
    -r, --rows [ROW_LIMIT]           Total number of rows to copy over
    -a, --copy-all                   Flag to copy dataset
    -h, --help                       Displays help
```

### Options

```ruby
options[:source_domain] # SOURCE_DOMAIN
options[:source_token] # SOURCE_APP_TOKEN
options[:target_domain] # TARGET_DOMAIN
options[:target_token] # TARGET_TOKEN
options[:soda_fountain] # SODA_FOUNTAIN_IP
options[:row_limit] # number of rows to copy
options[:source_id] # four by four of dataset to copy
```


# Nbe::Dataset::Migrator

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/nbe/dataset/migrator`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nbe-dataset-migrator'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nbe-dataset-migrator

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/nbe-dataset-migrator/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
