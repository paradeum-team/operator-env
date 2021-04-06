#!/bin/bash

host=""
user=""
password=""
database=""
sqlfile=""

if [ $HOST ];then
    host=${HOST}
else
    echo "host env is not exists"
    exit 1
fi

if [ $USER ];then
    user=${USER}
else
    echo "user env is not exists"
    exit 1
fi

if [ $PASSWORD ];then
    password=${PASSWORD}
else
    echo "password env is not exists"
    exit 1
fi

if [ $DATABASE ];then
    database=${DATABASE}
else
    echo "database env  is not exists"
    exit 1
fi

if [ $SQLFILE ];then
    sqlfile=${SQLFILE}
else
    echo "sqlfile env is not exists"
    exit 1
fi

# check daatabse;
mysql -h $host -u$user -p$password  -e "show databases;" > databases.txt

if [ "`cat databases.txt |grep -c $database`" != 0 ];then
 echo "database $database exist,continue ... "
else
 echo "database $database non-existent,abnormal termination"
 exit 1
fi

# check tables;
mysql -h $host -u$user -p$password --database=$database -e "show tables;" > tables.txt

echo "######### Start show tables; ##########"

filename=tables.txt
filesize=`ls -l $filename | awk '{ print $5 }'`

if [ $filesize -eq 0 ]
then
  mysql -h $host -u$user -p$password --database=$database < $sqlfile > sqlresult.txt
  echo "######### Start init sql; ##########"

  sqlresultsize=`ls -l sqlresult.txt | awk '{ print $5 }'`
  if [ $sqlresultsize -ne 0 ]
  then
   cat sqlresult.txt
   exit 1
  else
   sh apollo_updatesql.sh
   echo "######### Sql init end; ###########"
  fi
else
  cat tables.txt
  echo "######## Sql exist,do not create duplicate; #########"
fi
