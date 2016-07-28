#!/bin/bash

# command line args define the number of executors
boxes=$@

# sweep the number of executors to run
for box in ${boxes[*]}
do
    YARN_OPTS="--master yarn --deploy-mode cluster --num-executors ${box} --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192" 
    cmd="time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- transform"

    output="${input}.${box}"
    
    # mark dups
    ${cmd} \
	${hdfs_loc}/${input}.adam \
	${hdfs_loc}/${output}.mkdup.adam \
	-mark_duplicate_reads \
	-aligned_read_predicate \
	-limit_projection
    ${cmd} \
	${nfs_loc}/${input}.adam \
	${nfs_loc}/${output}.mkdup.adam \
	-mark_duplicate_reads \
	-aligned_read_predicate \
	-limit_projection

    
    # realign
    ${cmd} \
	${hdfs_loc}/${output}.mkdup.adam \
	${hdfs_loc}/${output}.ri.adam \
	-realign_indels
    ${cmd} \
	${nfs_loc}/${output}.mkdup.adam \
	${nfs_loc}/${output}.ri.adam \
	-realign_indels
    
    # bqsr
    ${cmd} \
	${hdfs_loc}/${output}.ri.adam \
	${hdfs_loc}/${output}.bqsr.adam \
	-recalibrate_base_qualities
    ${cmd} \
	${nfs_loc}/${output}.ri.adam \
	${nfs_loc}/${output}.bqsr.adam \
	-recalibrate_base_qualities
    
    # sort and single
    ${cmd} \
	${hdfs_loc}/${output}.bqsr.adam \
	${hdfs_loc}/${output}.final.bam \
	-sort_reads \
	-single
    ${cmd} \
	${nfs_loc}/${output}.bqsr.adam \
	${nfs_loc}/${output}.final.bam \
	-sort_reads \
	-single

done
