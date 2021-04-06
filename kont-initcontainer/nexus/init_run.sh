#!/bin/sh

is_empty_dir(){ 
    return `ls -A nexus-data|wc -w`
}

if is_empty_dir nexus-data
then
    mv data/* nexus-data/
    chown -R 200:200 nexus-data
else
    echo " nexus-data is not empty, data exist!" 
fi


