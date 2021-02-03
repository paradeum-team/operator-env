# apollo operator
**概述：**Apollo（阿波罗）是携程框架部门研发的分布式配置中心，能够集中化管理应用不同环境、不同集群的配置，配置修改后能够实时推送到应用端，并且具备规范的权限、流程治理等特性，适用于微服务配置管理场景。

- 1、用户在配置中心对配置进行修改并发布
- 2、配置中心通知Apollo客户端有配置更新
- 3、Apollo客户端从配置中心拉取最新的配置、更新本地配置并通知到应用

---

**有两种部署方式**

- helm
- yaml



## 1、基础环境准备
### 1.1 创建namespace
```
kubectl create ns sre
```
### 1.2 部署 mysql 
```
#host
host=mysql.sre
#
username=root
pwd=root1234	
```

### 1.3、下载最新镜像
- alpine-bash:3.8

- docker pull apolloconfig/apollo-configservice:1.7.2
 	
 	```
 	docker run -p 8080:8080 \
    -e SPRING_DATASOURCE_URL="jdbc:mysql://fill-in-the-correct-server:3306/ApolloConfigDB?characterEncoding=utf8" \
    -e SPRING_DATASOURCE_USERNAME=FillInCorrectUser -e SPRING_DATASOURCE_PASSWORD=FillInCorrectPassword \
    -d -v /tmp/logs:/opt/logs --name apollo-configservice apolloconfig/apollo-configservice:${version}
 	```
 	
- docker pull apolloconfig/apollo-adminservice:1.7.2
 	
 	```
 	docker run -p 8090:8090 \
    -e SPRING_DATASOURCE_URL="jdbc:mysql://fill-in-the-correct-server:3306/ApolloConfigDB?characterEncoding=utf8" \
    -e SPRING_DATASOURCE_USERNAME=FillInCorrectUser -e SPRING_DATASOURCE_PASSWORD=FillInCorrectPassword \
    -d -v /tmp/logs:/opt/logs --name apollo-adminservice apolloconfig/apollo-adminservice:${version}
 	```
 	
- docker pull apolloconfig/apollo-portal:1.7.2
	
	```
	docker run -p 8070:8070 \
    -e SPRING_DATASOURCE_URL="jdbc:mysql://fill-in-the-correct-server:3306/ApolloPortalDB?characterEncoding=utf8" \
    -e SPRING_DATASOURCE_USERNAME=FillInCorrectUser -e SPRING_DATASOURCE_PASSWORD=FillInCorrectPassword \
    -e APOLLO_PORTAL_ENVS=dev,pro \
    -e DEV_META=http://fill-in-dev-meta-server:8080 -e PRO_META=http://fill-in-pro-meta-server:8080 \
    -d -v /tmp/logs:/opt/logs --name apollo-portal apolloconfig/apollo-portal:${version}
	```

## 2、部署方式一：使用helm 部署
### 2.1 添加 repo
```
helm repo add apollo http://ctripcorp.github.io/apollo/charts
```

### 2.2 下载离线chart
```
helm pull apollo/apollo-service

# apollo-service-0.1.2.tgz
```

### 2.3 初始化数据
向mysql中导入数据：

- [apolloPortalDb.sql](https://github.com/ctripcorp/apollo/blob/master/scripts/sql/apolloportaldb.sql)
- [apolloconfigdb.sql](https://github.com/ctripcorp/apollo/blob/master/scripts/sql/apolloconfigdb.sql)



### 2.4 Deployments apollo-configservice and apollo-adminservice 

### 2.4.1 install 
注意：`configdb.service.enabled=false`，如果mysql 没有service 需要独立创建，则配置`true`

```
helm install apollo-service apollo-service-0.1.2.tgz\
    --set configdb.host=mysql.sre\
    --set configdb.userName=root\
    --set configdb.password=root1234\
    --set configdb.service.enabled=false\
    --set configService.replicaCount=1\
    --set adminService.replicaCount=1\
    -n sre
```

### 2.4.2 扩缩
应用实例数扩大到2

```
helm upgrade apollo-service  apollo-service-0.1.2.tgz\
    --set configdb.host=mysql.sre\
    --set configdb.userName=root\
    --set configdb.password=root1234\
    --set configdb.service.enabled=false\
    --set configService.replicaCount=2\
    --set adminService.replicaCount=2\
    -n sre 
```


### 2.4.3 卸载
```
helm uninstall apollo-service  -n sre 
```

### 2.5 Deployments of apollo-portal

### 2.5.1 install 
```
helm install apollo-portal apollo-portal-0.1.2.tgz\
    --set portaldb.host=mysql.sre\
    --set portaldb.userName=root\
    --set portaldb.password=root1234\
    --set portaldb.service.enabled=false\
    --set config.envs="dev" \
    --set config.metaServers.dev=http://apollo-service-apollo-configservice.sre:8080\
    --set replicaCount=1 \
    -n sre 
   
```

### 2.5.2 扩缩
```
helm upgrade apollo-portal apollo-portal-0.1.2.tgz\
    --set portaldb.host=mysql.sre\
    --set portaldb.userName=root\
    --set portaldb.password=root1234\
    --set portaldb.service.enabled=false\
    --set config.envs="dev" \
    --set config.metaServers.dev=http://apollo-service-apollo-configservice.sre:8080\
    --set replicaCount=2 \
    -n sre 
   
```
### 2.5.3 卸载
```
helm uninstall apollo-portal  -n sre 
```

## 3、部署方式二：使用yaml安装（db验证有点bug）
### 3.1 准备mysql 环境
- **用户名/密码:**root/root1234
- **ip:**


### 3.2 下载yaml 模板
[模板存放位置](https://github.com/ctripcorp/apollo/blob/master/scripts/apollo-on-kubernetes/README.md)

在模板的基础上，按照实际替换

-  mysql 数据库用户名密码
-  mysql可访问host


### 3.4 初始化数据
按照选择环境，初始化对应的db脚本
 
### 3.5 执行部署
查看 `kubectl-apply.sh` 脚本，按照环境选择模板，替换db相关配置，执行即可。



## 4、 访问验证
暴露端口访问portal

```
 export POD_NAME=$(kubectl get pods --namespace sre -l "app=apollo-portal" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8070 to use your application"
  kubectl --namespace sre port-forward $POD_NAME 8070:8070
```

`http://localhost:8070/`

**用户名/密码：**`apollo/admin`



### 参考资料
- [docker huber 镜像地址](https://hub.docker.com/u/apolloconfig)
- [apollo 文档](https://ctripcorp.github.io/apollo/#/zh/design/apollo-design)
- [apollo 源码](https://github.com/ctripcorp/apollo)
- [apollo on k8s](https://github.com/ctripcorp/apollo/blob/master/scripts/apollo-on-kubernetes/README.md)