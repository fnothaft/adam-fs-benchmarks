#!/bin/bash

set -x -v

# get a temp directory for building adam
ADAM_TEMP=$( mktemp -d -t adamXXXXXXXX )

# cd there and checkout adam
cd ${ADAM_TEMP}
export ADAM_HOME=${ADAM_TEMP}/adam
git clone https://github.com/bigdatagenomics/adam

# is maven installed? if not, download and unpack
if [ -n "${MAVEN_HOME}" ];
then
    MAVEN=$( which mvn )
    if [ -n "${MAVEN}" ];
    then
        # find mirror
        mirror=$(python -c "from urllib2 import urlopen; import json; print json.load( urlopen('http://www.apache.org/dyn/closer.cgi?path=$path&asjson=1'))['preferred']")
        
        # make a directory for maven 
        mkdir ${ADAM_TEMP}/apache-maven-3.3.9
        curl ${mirror}maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz \
            | tar --strip-components=1 -xzC ${ADAM_TEMP}/apache-maven-3.3.9

        # set path to maven
        MAVEN=${ADAM_TEMP}/apache-maven-3.3.9/bin/maven
    fi
else
    MAVEN=${MAVEN_HOME}/bin/maven
fi
export MAVEN

# build
cd adam
${MAVEN} package -DskipTests

# set the hdfs and nfs directories
# ASSUMPTION: this is getting run from the same node that serves as the HDFS
# namenode, and the namenode is at port 8080
namenode=$(hostname -f)
HDFS_PORT=8020
hdfs_loc=hdfs://${namenode}:${HDFS_PORT}/data/adam_test/
nfs_loc=file:///mnt/fb/adam_test/
input=$1

YARN_OPTS="--master yarn --deploy-mode cluster --num-executors 31 --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192"
cmd="time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- transform"

# convert to adam
${cmd} ${hdfs_loc}/${input}.bam \
    ${hdfs_loc}/${input}.adam

# run flagstat
boxes=( 32 16 8 4 2 1 )
for box in ${boxes[*]}
do
    YARN_OPTS="--master yarn --deploy-mode cluster --num-executors ${box} --executor-memory 200g --executor-cores 16 --driver-memory 8g --conf spark.driver.maxResultSize=0 --conf spark.yarn.executor.memoryOverhead=8192"

    time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- flagstat ${hdfs_loc}/${input}.adam
    time ${ADAM_HOME}/bin/adam-submit ${YARN_OPTS} -- flagstat ${nfs_loc}/${input}.adam
done

# run pipeline
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