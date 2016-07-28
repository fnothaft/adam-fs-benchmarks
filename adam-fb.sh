#!/bin/bash

set -e

# build adam
if [ -n "${ADAM_HOME}" ]
then
    ./build-adam.sh
fi

# set the hdfs and nfs directories
# ASSUMPTION: this is getting run from the same node that serves as the HDFS
# namenode, and the namenode is at port 8080
namenode=$(hostname -f)
HDFS_PORT=8020
export hdfs_loc=hdfs://${namenode}:${HDFS_PORT}/data/adam_test/
export nfs_loc=file:///mnt/fb/adam_test/
input=$1

# run flagstat
boxes=( 32 16 8 4 2 1 )
./run-flagstat.sh ${boxes}

# run pipeline
./run-pipeline.sh ${boxes}