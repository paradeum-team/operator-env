#### Kont初始化镜像制作

#### 一、介质目录

```
.
├── Dockerfile
├── activiti_dev.sql
├── apolloconfigdb.sql
├── apolloportaldb.sql
├── base_dev.sql
├── ddep_demo.sql
├── import.sh
├── kont_dev.sql
├── metadata_dev.sql
├── mysql
├── run.sh
├── update.sql
└── xxl_job.sql

```

#### 二、初始化说明

- 当前只支持如下服务的sql初始化：activiti_dev、apolloconfigdb、apolloportaldb、base_dev、kont_dev、metadata_dev、xxl_job
- 如果需要初始化其他服务的sql，重新定制镜像，将sql加入到同级目录即可。
- 当前可用最新初始化镜像： 
	- xxx/library/kont-sqlinit:0.0.7

#### 三、Dockerfile

```
FROM centos:7
COPY mysql /usr/bin/mysql
RUN  chmod 777 /usr/bin/mysqlimage
COPY import.sh .
COPY *.sql /
ENTRYPOINT ["./import.sh"]
```

- 基础镜像中没有mysql客户端，所以用了一个linux版本mysql客户端，放在容器/usr/bin/目录下，可直接执行。

#### 四、import.sh 容器启动后的执行脚本

```
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
```

- 定义mysql连接相关参数，sql脚本的名称。
- 检查数据库是否存在，数据库不存在，则服务init失败。
- 初始化sql前判断表是否存在，不存在则创建。

#### 五、执行步骤,示例

- docker build -t xxx/library/kont-sqlinit:0.0.1 .

- run.sh 本地调试，容器内调试

	```
	docker run -it \
	-e HOST="192.168.0.124" \
	-e USER="xxl_job" \
	-e PASSWORD="Hisun.11"	\
	-e DATABASE="xxl_job" \
	-e SQLFILE="xxl_job.sql" \
	xxx/library/kont-sqlinit:0.0.4 bash
	
	```

#### TODO

- 初始化脚本升级
- 新增服务sql init，是否可以采用目录挂载，或者是用一个http服务获取sql，不频繁更新镜像。

#### END