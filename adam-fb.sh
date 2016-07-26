#!/bin/bash

set -x -v

ADAM_HOME=~/adam
hdfs_loc=file:///mnt/fb/adam_test/
input=$1
suffix=$2
output="${input}${suffix}"

#YARN_OPTS="--master yarn --deploy-mode cluster --num-executors 31 --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192 --conf spark.yarn.am.nodeLabelExpression=flashblade --conf spark.yarn.executor.nodeLabelExpression=flashblade --conf spark.hadoop.fs.default.name=file:/// --conf spark.local.dir=/home/eecs/fnothaft/tmp --conf spark.yarn.preserve.staging.files=true"
#YARN_OPTS="--master yarn --deploy-mode cluster --num-executors 31 --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192 --conf spark.yarn.am.nodeLabelExpression=flashblade --conf spark.yarn.executor.nodeLabelExpression=flashblade --conf spark.hadoop.fs.default.name=file:/// --conf spark.local.dir=/mnt/fb/adam_test/tmp --conf spark.yarn.preserve.staging.files=true"
YARN_OPTS="--master yarn --deploy-mode cluster --num-executors 31 --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192"
cmd="time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- transform"

# convert to adam
#${cmd} ${hdfs_loc}/${input}.bam \
#    ${hdfs_loc}/${output}.adam

# run flagstat
boxes=( 31 16 8 4 2 1 )
for box in ${boxes[*]}
do
    YARN_OPTS="--master yarn --deploy-mode cluster --num-executors ${box} --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192"
    #YARN_OPTS="--master yarn --deploy-mode cluster --num-executors ${box} --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192 --conf spark.yarn.am.nodeLabelExpression=flashblade --conf spark.yarn.executor.nodeLabelExpression=flashblade --conf spark.local.dir=/mnt/fb/adam_test/tmp --conf spark.yarn.preserve.staging.files=true"

    time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- flagstat ${hdfs_loc}/${output}.adam
done

# run pipeline

# dedup
for box in ${boxes[*]}
do
    YARN_OPTS="--master yarn --deploy-mode cluster --num-executors ${box} --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192" 
    cmd="time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- transform"

    output="${output}.${box}"
    
    ${cmd} \
	${hdfs_loc}/${output}.adam \
	${hdfs_loc}/${output}.mkdup.adam \
	-mark_duplicate_reads \
	-aligned_read_predicate \
	-limit_projection
    
    # realign
    ${cmd} \
	${hdfs_loc}/${output}.mkdup.adam \
	${hdfs_loc}/${output}.ri.adam \
	-realign_indels
    
    # bqsr
    ${cmd} \
	${hdfs_loc}/${output}.ri.adam \
	${hdfs_loc}/${output}.bqsr.adam \
	-recalibrate_base_qualities
    
    # sort and single
    ${cmd} \
	${hdfs_loc}/${output}.bqsr.adam \
	${hdfs_loc}/${output}.final.bam \
	-sort_reads \
	-single

done