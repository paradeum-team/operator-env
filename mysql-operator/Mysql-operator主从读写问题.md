### Mysql-operator主从读写问题

#### 问题描述

1. 发布mysql-opeator，并且发布mysql服务，此时mysql服务是主从模式。

2. 使用mysql的service，mysql-cluster-mysql.mysql-system:3306进行访问。

3. 删除主mysql pod，slave进行数据同步。错误如下：
	
	```
	[ERROR] Slave I/O for channel '': error connecting to master 'sys_replication@//$release-mysqlcluster-db-mysql-0.mysql.$namespace:3306' - retry-time: 1  retries: 1755, Error_code: 2005
	```

#### 问题解决

#### issues

- https://github.com/presslabs/mysql-operator/issues/627
- bug未修复，以下是临时解决方案，还需要观察。

#### 原因

1. 因为默认mysql-operator在失败转移的时候slave节点支持写的，最终导致数据不一致，主从无法同步，陷入了死循环报错。

2. 应用访问mysql的时候使用的是 mysql-cluster-mysql.mysql-system:3306，不区分主从。如果应用没有明确使用读写分离数据库，只配置mysql master的svc支持写即可，mysql-cluster-mysql-master。

#### 解决

1. 重新部署mysql-operator，更改参数。设置为true，在失败转移的时候slave只读。

	```
	# `reset slave all` and `set read_only=0` on promoted master
    ApplyMySQLPromotionAfterMasterFailover: true
	
	```
	
2. 应用访问mysql使用mysql-cluster-mysql-master，默认只会发现master-pod

#### END