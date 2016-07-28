#!/bin/bash

# command line args define the number of executors
boxes=$@

# sweep the number of executors to run
for box in ${boxes[*]}
do
    YARN_OPTS="--master yarn --deploy-mode cluster --num-executors ${box} --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192"
    echo "Running flagstat on ${box} executors with data in HDFS." 1>&2
    time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- flagstat ${hdfs_loc}/${input}.adam
    
    echo "Running flagstat on ${box} executors with data in HDFS." 1>&2
    time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- flagstat ${nfs_loc}/${input}.adam
done

