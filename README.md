nbe-dataset-migrator
=============================
Migrates NBE datasets between environments

### Overview

This is a gem to help with NBE->NBE dataset migrations.
It works by providing a DatasetMigration class that exposes the various steps required to migrate a dataset, including:
* Fetch dataset metadata from the source environment
* Create dataset with the same name in the target environment
* Create standard columns in the new dataset
* Find any computed columns in source dataset, and the curated regions they reference
* Migrate over the curated regions to target environment (using DataSync with NBE support)
* Create the computed columns in the new dataset, referencing the new curated regions
* Copy over data using the SODA2 REST API
* Publish

### Installation
To use the gem in a local project, include the following in the project's Gemfile:
```ruby
gem 'nbe-dataset-migrator', git: 'git@github.com:socrata/nbe-dataset-migrator'
```
If you are interested in using the command line utility, simply install the gem locally. To do this, clone this repo and run the following commands from the root of the repo directory:
```bash
$ bundle install
$ rake install
```
After installing the gem you should be able to use the `dataset_migrator` utility from the command line.
* The gem should support ruby versions 1.9.3 and up.

### Running the command line utility
* Looks for Socrata username & password from environment variables: `$SOCRATA_USER` & `$SOCRATA_PASSWORD`
* Note: you should make sure this is a super-admin account, and the password should be shared across environments
* Get DataSync jar with ability to port into NBE from this repo or by downloading it from [here](https://drive.google.com/a/socrata.com/file/d/0Bz5SGM6croe5Tnc0ZnkzWkVTVDg/view?usp=sharing).
* Run using the following command:

```bash
$ dataset_migrator -d [DATASET_ID] \
  --sd https://dataspace.demo.socrata.com \
  --st [SOURCE_APP_TOKEN] \
  --td https://opendata-demo.test-socrata.com \
  --tt [TARGET_APP_TOKEN] --sf [SODA_FOUNTAIN_IP] \
  --rows 20000 \
  --dj resources/DataSync-1.5.4-nbe-capable.jar
```
Usage instructions:
```
Usage: dataset_migrator [options]
    -d, --dataset [DATASET_ID]       Dataset to migrate to target environment.
        --sd [DOMAIN]                Source domain
        --st [TOKEN]                 Source app token
        --td [DOMAIN]                Target domain
        --tt [TOKEN]                 Target app token
        --sf [SODA_FOUNTAIN_IP]      IP Address for Soda Fountain (requires VPN)
    -r, --rows [ROW_LIMIT]           Total number of rows to copy over, if blank, copies top 500,000
        --[no-]publish               Publish dataset after end of migration, default is to publish
        --dj [PATH_TO_JAR]           Path to NBE-capable Datasync jar
                                     If not present, will skip migrate regions/create computed columns
    -h, --help                       Displays help
```

### Using the gem

Create the DatasetMigrator by passing in an options hash, with the following keys:

```ruby
require 'nbe-dataset-migrator'

options = {
  user: ENV['SOCRATA_USER'],
  password: ENV['SOCRATA_PASSWORD'],
  source_domain: 'https://dataspace.demo.socrata.com',
  source_token: '[APP_TOKEN]',
  target_domain: 'https://opendata-demo.test-socrata.com',
  target_token: '[APP_TOKEN]',
  soda_fountain_ip: '[SODA_FOUNTAIN_IP]', # IP address for source environment Soda Fountain
  source_id: '[FOUR-BY-FOUR]',
  publish: true,
  row_limit: 100_000
  datasync_jar: 'resources/DataSync-1.5.4-nbe-capable.jar'
}

migrator = NBE::DatasetMigrator.new(options)
migrator.run
```
