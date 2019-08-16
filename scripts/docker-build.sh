#!/bin/bash

script_dirirectory="$( cd "$( dirname "$0" )" && pwd )"
project_dirirectory=$script_dirirectory/..
echo $project_dirirectory
cd $project_dirirectory

docker build --tag="aandrewww/alpine-openresty-extended:1.0" .
