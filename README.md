# Presto - Hive - Azure Storage Example

This project is an example of how [Presto](https://prestodb.io) _Distributed SQL Query Engine for Big Data_ can be configured to run on a desktop machine with the [Hive Connector](https://prestodb.io/docs/current/connector/hive.html) configured for an Azure Blob Storage account to query blob data using SQL.

:construction: This has only been tested on Windows 10 running WSL2 with Ubuntu 18.04.

## Install Dependencies

### Docker

Install Docker as this project will reuse the Presto [example deployment with Docker](https://prestodb.io/docs/current/installation/deployment.html#an-example-deployment-with-docker).

### Java

This project will use the Hive connector which needs Hive Metastore that depends on Java.

:warning: Hive 3.0 (and Hadoop which it's built upon) only supports Java 8. 

Despite this warning I managed to run the Metastore component using Zulu OpenJDK 11 on Ubuntu.

`sudo apt install zulu11-jdk`

### Hive Metastore

Although Presto doesn't need a full Hive installation to be running, a remote Hive Metastore is needed to record metadata about how the data files are mapped to schemas and tables.

Metastore can be configured to use a traditional RDBMS such as MySQL but for this example we will use the local embedded Derby database which is the default configuration.

Since Hive v3.0 [the Metastore is released as a separate package](https://cwiki.apache.org/confluence/display/Hive/AdminManual+Metastore+3.0+Administration#AdminManualMetastore3.0Administration-RunningtheMetastoreWithoutHive). This would be perfect to use for this project except that the [Hive connector documentation](https://prestodb.io/docs/current/connector/hive.html) only mentions support for Hadoop 2.x.

> The Hive connector supports Apache Hadoop 2.x and derivative distributions including Cloudera CDH 5 and Hortonworks Data Platform (HDP).

However, it seems to work when I've tested it so this project will use `hive-standalone-metastore-3.0.0`.

Running Metastore relies on Hadoop libraries and `JAVA_HOME` `HIVE_HOME` and `HADOOP_HOME` environment variables.

Hadoop doesn't need to be running :tada:.

To set everything up run script [run_metastore.sh](/run_metastore.sh).

```
./run_metastore.sh
```

On first run this script will download and unpack the Hadoop and Hive Metastore dependencies, set the environment variables, initialise the Derby database schema, and run Metastore, finishing with the log messages:

```
Initialization script completed
schemaTool completed
Starting Metastore
```

### Azure Storage Account

As this project is an example of Presto with Azure Blob Storage you will need an Azure Storage account if you don't already have one.

I used type `StorageV2 (general purpose v2)`.

Within the Storage Account create a new private Container.

Take a note of the account name, primary access key and container name which will be used to configure the Hive Metastore and Hive connector.

Note: I was unsuccessful at configuring the Hive connector to use Microsoft Azure Storage Emulator. The configuration expects a remote endpoint `<storage-account-name>.blob.core.windows.net`.

In `apache-hive-metastore\apache-hive-metastore-3.0.0-bin\conf\metastore-site.xml` add a new property with name `fs.azure.account.key.<storage-account-name>.blob.core.windows.net` replacing the name of the Azure Storage account and access key.

```
  <property>
    <name>fs.azure.account.key.<storage-account-name>.blob.core.windows.net</name>
    <value>your-access-key-here</value>
  </property>
```

Now restart Metastore.

```
./run_metastore.sh
```

### Configure Presto

The [Docker Compose file](/docker-compose.yml) mounts the Presto configuration directory with a relative host path.

Review all of the Presto configuration in [/presto/etc](/presto/etc) such as [config.properties](/presto/etc/config.properties) and [jvm.config](/presto/etc/jvm.config).

[/presto/etc/catalog](/presto/etc/catalog) contains the Connector configuration.

The [TPCH Connector](https://prestodb.io/docs/current/connector/tpch.html) is added for benchmarking.

The [Hive Connector](https://prestodb.io/docs/current/connector/hive.html) is added for querying data in Azure Storage.

### Configure Hive Connector

Review the Hive connector properties in [/presto/etc/catalog/hive.properties](/presto/etc/catalog/hive.properties).

Metastore is running on the host rather than running in Docker so the Metastore URI is `thrift://host.docker.internal:9083`.

Permissions can be configured such as `hive.allow-drop-table` and `hive.non-managed-table-writes-enabled`.

Presto requires additional HDFS configuration with the Storage Account credentials. This configuration is in [azure-site.xml](/presto/etc/azure-site.xml).

Set the property with name `fs.azure.account.key.<storage-account-name>.blob.core.windows.net` replacing the name of the Azure Storage account and access key.

```
  <property>
    <name>fs.azure.account.key.<storage-account-name>.blob.core.windows.net</name>
    <value>your-access-key-here</value>
  </property>
```

More information about this Hadoop configuration file and how to encrypt the Azure credentials can be found [here](https://hadoop.apache.org/docs/current/hadoop-azure/index.html).

## Startup

### Start Metastore

```
./run_metastore.sh
```

### Start Presto

```
docker-compose -p prestodemo up
```

### Start Presto CLI

```
docker-compose -p prestodemo exec presto presto
```

## Using Presto

See https://prestodb.io/docs/current/connector/hive.html#examples for more examples.

### Browse the Presto UI

http://localhost:8080/ui

### Query all nodes

```
SELECT * FROM system.runtime.nodes;
```

### List all schemas

```
SHOW SCHEMAS FROM system;
```

### Create a new schema

To create a new schema based in the Storage Account container `<container-name>@<storage-account-name>.blob.core.windows.net`:

```
CREATE SCHEMA hive.<schema-name> WITH (location = 'wasbs://<container-name>@<storage-account-name>.blob.core.windows.net/');
```

### Switch schema

```
USE hive.<schema-name>;
```

### Create an empty external table in Azure Storage

E.g. to create an empty external table in text format with column definition `(id int, name varchar(255))` in a folder located in the Storage Account container `<container-name>@<storage-account-name>.blob.core.windows.net/<folder-name>`:

```
CREATE TABLE <table-name> (id int, name varchar(255)) WITH (format='TEXTFILE',external_location='wasbs://<container-name>@<storage-account-name>.blob.core.windows.net/<folder-name>');
```

You can then insert new rows:

```
INSERT INTO <table-name> (id, name) VALUES (1, 'test');
```

After the insert is finished you should see a data file appear in the container and you can now query the data.

```
presto> SELECT * FROM <table-name>;
 id | name
----+------
  1 | test
(1 row)
```

Note: The folder needs to exist prior to creating the table but I found no way to create an empty folder. I uploaded a dummy file to my container to create a folder and then deleted it once the data file is created.

### Create an external table based on existing data in Azure Storage

Use the same command if the folder already contains existing data files.

E.g. to create an external table based on existing data in Parquet format with column definition `(id int, name varchar(255))` in a folder located in the Storage Account container `<container-name>@<storage-account-name>.blob.core.windows.net/<folder-name>`:

Individual filenames are not specified in `external_location`, only the parent folder.

```
CREATE TABLE <table-name> (id int, name varchar(255)) WITH (format='PARQUET',external_location='wasbs://<container-name>@<storage-account-name>.blob.core.windows.net/<folder-name>');
```

### Supported formats

See https://prestodb.io/docs/current/connector/hive.html#supported-file-types.

### Run a query

Presto supports ANSI SQL to insert and query data in tables.

### Drop a table

```
DROP TABLE <table-name>;
```

## Troubleshooting

### Presto unable to access Metastore

The Metastore URI is defined as `hive.metastore.uri=thrift://host.docker.internal:9083` in [/presto/etc/catalog/hive.properties](/presto/etc/catalog/hive.properties).

Metastore is running on the host rather than running in Docker which is why the address is `host.docker.internal`.

I had a problem where I could `telnet localhost 9083` in WSL2 but Windows was not forwarding this port and the Presto container couldn't access port 9083.

When running any query I got an error such as `Query 20210122_231557_00000_mq2qm failed: Failed connecting to Hive metastore: [host.docker.internal:9083]`.

To fix this I had to run the following as Administrator in PowerShell to forward the port:

```
netsh interface portproxy add v4tov4 listenport=9083 listenaddress='0.0.0.0' connectport=9083 connectaddress='<WSL2-Ip-Address>'
```

You can check this with:

```
netsh interface portproxy show v4tov4
```