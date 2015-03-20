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
