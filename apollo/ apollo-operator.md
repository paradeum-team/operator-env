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
	todo

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

## 2、使用helm 部署
### 2.1 添加 repo
```
helm repo add apollo http://ctripcorp.github.io/apollo/charts
 
```

### 2.2 下载离线chart
```
helm pull apollo/apollo-service

# apollo-service-0.1.2.tgz
```

### 2.3 install 
```
helm install apollo-dev apollo-service-0.1.2.tgz\
    --set configdb.host=10.103.157.172 \
    --set configdb.userName=root \
    --set configdb.password=root1234 \
    --set configdb.service.enabled=true \
    --set configService.replicaCount=1 \
    --set adminService.replicaCount=1 \
    -n sre 
```


### 2.3 扩缩

### 2.4 卸载
```
helm install apollo-dev -n sre 
```





### 参考资料
- [docker huber 镜像地址](https://hub.docker.com/u/apolloconfig)
- [apollo 文档](https://ctripcorp.github.io/apollo/#/zh/design/apollo-design)
- [apollo 源码](https://github.com/ctripcorp/apollo)