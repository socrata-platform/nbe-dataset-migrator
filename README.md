nbe-dataset-migrator
=============================
Migrates NBE datasets between environments

### Overview

This is a gem to help with NBE->NBE dataset migrations.
It works by providing a DatasetMigration class that exposes discrete actions, and has the capability of doing:
* Fetch dataset metadata from the source environment
* Create dataset with the same name in the target environment
* Create the standard columns in the new dataset
* Find any computed columns in source dataset, and the curated regions they reference
* Migrate over the curated regions to target environment (using DataSync)
* Create the computed columns in the new dataset, referencing the new curated regions
* Copy over data using the SODA2 REST API
* Publish

### Running the command line utility

* Install the gem globally
* Uses ruby 2.2.1
* Looks for Socrata username & password from environment variables: `$SOCRATA_USER` & `$SOCRATA_PASSWORD`
* Get DataSync jar with ability to port into NBE, [here](https://drive.google.com/a/socrata.com/file/d/0Bz5SGM6croe5Tnc0ZnkzWkVTVDg/view?usp=sharing).
* Run using the following command:

```
dataset_migrator -d [DATASET_ID] --sd https://dataspace.demo.socrata.com --st [SOURCE_APP_TOKEN] --td https://opendata-demo.test-socrata.com --tt [TARGET_APP_TOKEN] --sf [SODA_FOUNTAIN_IP] --rows 20000 --dj DataSync-1.5.4-nbe-capable.jar
```

```
Usage: dataset_migrator [options]
    -d, --dataset [DATASET_ID]       Dataset to migrate to target environment.
        --sd [DOMAIN]                Source domain
        --st [TOKEN]                 Source app token
        --td [DOMAIN]                Target domain
        --tt [TOKEN]                 Target app token
        --sf [SODA_FOUNTAIN_IP]      IP Address for Soda Fountain (requires VPN)
    -r, --rows [ROW_LIMIT]           Total number of rows to copy over
        --dj [PATH_TO_JAR]           Path to NBE-capable Datasync jar
    -h, --help                       Displays help
```

### Options

Create the DatasetMigrator using an options hash, with the following keys:

```ruby
options[:source_domain]
options[:source_token]
options[:target_domain]
options[:target_token]
options[:soda_fountain_ip] # ip address of source environment Soda Fountain server
options[:source_id] # four by four of dataset to copy on source domain
options[:datasync_jar] # relative path to datasync jar

migrator = NBE::DatasetMigrator.new(options)
```
