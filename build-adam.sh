#!/bin/bash

# get a temp directory for building adam
ADAM_TEMP=$( mktemp -d -t adamXXXXXXXX )
echo "Made temp directory ${ADAM_TEMP} for building ADAM." 1>&2

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
        
        echo "Couldn't find maven on path!" 1>&2

        # find mirror
        mirror=$(python -c "from urllib2 import urlopen; import json; print json.load( urlopen('http://www.apache.org/dyn/closer.cgi?path=$path&asjson=1'))['preferred']")
        echo "Downloading maven from ${mirror}." 1>&2

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
echo "Building ADAM." 1>&2
cd adam
${MAVEN} package -DskipTests
