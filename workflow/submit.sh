#!/bin/bash

set -e

TOP_DIR=`dirname $0`
TOP_DIR=`cd $TOP_DIR/.. && pwd`
cd $TOP_DIR

# does the required config files exist?
if [ ! -e "$TOP_DIR/mint_run.config" ]; then
    echo "Required file mint_run.config does not exist"
    exit 1
fi

export RUN_ID=mint-`date +'%s'`
export RUN_DIR=/local-scratch/$USER/workflow/$RUN_ID

mkdir -p $RUN_DIR
mkdir -p workflow/generated

# set up the replica catalog, if one is provided
if [ "X$1" != "X" ]; then
    cp "$1" $RUN_DIR/replica.data
fi

# create a site catalog from the template
envsubst < workflow/sites.template.xml > workflow/generated/sites.xml

# generate a transformation catalog
./workflow/tc-generator.sh >workflow/generated/tc.data

# generate the workflow
./workflow/dax-generator.py

# plan and submit
pegasus-plan \
    -Dpegasus.catalog.replica.file=$RUN_DIR/replica.data \
    --conf workflow/pegasus.conf \
    --sites condor_pool \
    --output-site local \
    --cleanup none \
    --relative-dir $RUN_ID \
    --dir $RUN_DIR \
    --dax workflow/generated/dax.xml \
    --submit



