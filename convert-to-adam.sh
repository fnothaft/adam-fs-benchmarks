#!/bin/bash

export YARN_OPTS="--master yarn --deploy-mode cluster --num-executors 31 --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192"
cmd="time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- transform"

# convert to adam
echo "Converting input file from BAM to ADAM." 1>&2
${cmd} ${hdfs_loc}/${input}.bam \
    ${hdfs_loc}/${input}.adam $@
${cmd} ${nfs_loc}/${input}.bam \
    ${nfs_loc}/${input}.adam $@
