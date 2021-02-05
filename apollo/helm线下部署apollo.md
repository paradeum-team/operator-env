# 使用helm 线下部署apollo
部署环境依赖mysql服务。

mysql 部署请参考mysql部署


## 1、基础环境准备
### 1.1 创建namespace
```
kubectl create ns sre
```
### 1.2 部署 mysql 

**查看mysql的svc**

```
kubectl get svc -n db
# output
NAME    TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
mysql   ClusterIP   10.97.48.62   <none>        3306/TCP   2m6s
```

**具体配置：**

```
#host
host=mysql.db
#
username=root
pwd=root1234	
```

## 2、下载相关镜像并推送到私有仓库
**私有仓库地址：**`registry.hisun.netwarps.com`

**镜像 List:**

- apolloconfig/apollo-configservice:1.7.2
- apolloconfig/apollo-adminservice:1.7.2
- apolloconfig/apollo-portal:1.7.2
	


## 3、下载离线的chart
 
```
# 添加repo
helm repo add apollo http://ctripcorp.github.io/apollo/charts
helm repo update

# 下载chart到本地
helm pull apollo/apollo-service
helm pull apollo/apollo-portal

# apollo-service-0.1.2.tgz
```

## 4、 数据库初始化数据
向mysql中导入数据：

- [apolloPortalDb.sql](https://github.com/ctripcorp/apollo/blob/master/scripts/sql/apolloportaldb.sql)
- [apolloconfigdb.sql](https://github.com/ctripcorp/apollo/blob/master/scripts/sql/apolloconfigdb.sql)
	




## 5、 Deployments apollo-configservice and apollo-adminservice 

### 5.1 install 
注意：`configdb.service.enabled=false`，如果mysql 没有service 需要独立创建，则配置`true`

```
helm install apollo-service apollo-service-0.1.2.tgz\
    --set configdb.host=mysql.db\
    --set configdb.userName=root\
    --set configdb.password=root1234\
    --set configdb.service.enabled=false\
    --set configService.replicaCount=1\
    --set configService.image.repository=registry.hisun.netwarps.com/apolloconfig/apollo-configservice \
    --set adminService.image.repository=registry.hisun.netwarps.com/apolloconfig/apollo-adminservice \
    --set adminService.replicaCount=1\
    -n sre
```

### 5.2 扩缩
应用实例数扩大到2

```
helm upgrade apollo-service  apollo-service-0.1.2.tgz\
    --set configdb.host=mysql.db\
    --set configdb.userName=root\
    --set configdb.password=root1234\
    --set configdb.service.enabled=false\
    --set configService.image.repository=registry.hisun.netwarps.com/apolloconfig/apollo-configservice \
    --set adminService.image.repository=registry.hisun.netwarps.com/apolloconfig/apollo-adminservice \
    --set configService.replicaCount=2\
    --set adminService.replicaCount=2\
    -n sre 
```


### 5.3 卸载
```
helm uninstall apollo-service  -n sre 
```

## 6、Deployments of apollo-portal

### 6.1 install 
```
helm install apollo-portal apollo-portal-0.1.2.tgz\
    --set portaldb.host=mysql.db\
    --set portaldb.userName=root\
    --set portaldb.password=root1234\
    --set portaldb.service.enabled=false\
    --set image.repository=registry.hisun.netwarps.com/apolloconfig/apollo-portal \
    --set config.envs="dev" \
    --set config.metaServers.dev=http://apollo-service-apollo-configservice.sre:8080\
    --set replicaCount=1 \
    -n sre 
   
```

### 6.2 扩缩
```
helm upgrade apollo-portal apollo-portal-0.1.2.tgz\
    --set portaldb.host=mysql.db\
    --set portaldb.userName=root\
    --set portaldb.password=root1234\
    --set portaldb.service.enabled=false\
    --set image.repository=registry.hisun.netwarps.com/apolloconfig/apollo-portal \
    --set config.envs="dev" \
    --set config.metaServers.dev=http://apollo-service-apollo-configservice.sre:8080\
    --set replicaCount=2 \
    -n sre 
   
```
### 6.3 卸载
```
helm uninstall apollo-portal  -n sre 
```

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