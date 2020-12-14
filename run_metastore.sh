#!/bin/bash

readonly HADOOP_VERSION=3.1.4
readonly HADOOP_DISTRIBUTION=hadoop-$HADOOP_VERSION.tar.gz

readonly HIVE_METASTORE_VERSION=3.0.0
readonly HIVE_METASTORE_DISTRIBUTION=hive-standalone-metastore-$HIVE_METASTORE_VERSION-bin.tar.gz

export HADOOP_HOME=$(pwd)/hadoop/hadoop-$HADOOP_VERSION
export HIVE_HOME=$(pwd)/apache-hive-metastore/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin
export JAVA_HOME=/usr/lib/jvm/zulu11/
export METASTORE_AUX_JARS_PATH=${HADOOP_HOME}/share/hadoop/tools/lib/hadoop-azure-3.1.4.jar:${HADOOP_HOME}/share/hadoop/tools/lib/azure-storage-7.0.0.jar

mkdir -p downloads

# Download Hadoop
if [ -e "downloads/$HADOOP_DISTRIBUTION" ]; then
    echo 'Hadoop already downloaded' >&2
  else
    wget -O downloads/$HADOOP_DISTRIBUTION https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/$HADOOP_DISTRIBUTION
fi

# Download Hive Metastore
if [ -e "downloads/$HIVE_METASTORE_DISTRIBUTION" ]; then
    echo 'Hive metastore already downloaded' >&2
  else
    wget -O downloads/$HIVE_METASTORE_DISTRIBUTION https://downloads.apache.org/hive/hive-standalone-metastore-$HIVE_METASTORE_VERSION/$HIVE_METASTORE_DISTRIBUTION
fi

# Unpack Hadoop
if [ -e "hadoop" ]; then
    echo 'Hadoop already exists' >&2
  else
    mkdir hadoop
    tar -zxvf downloads/$HADOOP_DISTRIBUTION -C hadoop
fi

# Unpack Hive Metastore and initialise it
if [ -e "apache-hive-metastore" ]; then
    echo 'Hive metastore already exists' >&2
  else
    mkdir apache-hive-metastore
    tar -zxvf downloads/$HIVE_METASTORE_DISTRIBUTION -C apache-hive-metastore

    # Fix java.lang.NoSuchMethodError error creating schema, see https://issues.apache.org/jira/browse/HIVE-22915
    rm $HIVE_HOME/lib/guava-19.0.jar
    cp $HADOOP_HOME/share/hadoop/hdfs/lib/guava-27.0-jre.jar $HIVE_HOME/lib

    # Download log4j-web
    wget -O $HIVE_HOME/lib/log4j-web-2.8.2.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-web/2.8.2/log4j-web-2.8.2.jar

    # Initialise the schema
    pushd $HIVE_HOME
    echo Initialising schema
    bin/schematool -dbType derby -initSchema
    popd
fi

# Run Hive Metastore
cd $HIVE_HOME
echo Starting Metastore
bin/start-metastore
