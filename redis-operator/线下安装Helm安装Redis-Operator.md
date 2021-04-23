### 线下安装Helm安装Redis-Operator

### 1. 下载redis-operator chart

- [redis-operator-1.0.0.tgz](https://pnode.solarfs.io/dn/file/0c35cbf6b6caaba2db651681cde60d7f/redis-operator-1.0.0.tgz)

- 解压tgz，修改value.yaml，更改镜像

	```
	tar -zxvf redis-operator-1.0.0.tgz
	```
	
	修改values.yaml,把镜像推到内部镜像仓库，默认推到了registry.hisun.netwarps.com
        修改values.yaml,rbac的install为true，否则部署会出现权限问题
	
### 2. helm部署redis-operator

- 创建 namespace 
		
	```	
	 kubectl create namespace redis-system
	```
- 部署operator

	```
	helm install redis-operator redisoperator -n redis-system
	```
	
### 3. 部署redis服务   
- secret.yaml  
```
kind: Secret
apiVersion: v1
metadata:
  name: redis-auth
  namespace: redis-system
data:
  password: cnMxMjM=
type: Opaque
```

- enable-exporter.yaml 

```
	apiVersion: databases.spotahome.com/v1
kind: RedisFailover
metadata:
  name: redisfailover
spec:
  sentinel:
    replicas: 3
    exporter:
      enabled: true
      image: registry.hisun.netwarps.com/leominov/redis_sentinel_exporter:1.3.0
  redis:
    replicas: 3
    exporter: 
      enabled: true
      iimage: registry.hisun.netwarps.com/oliver006/redis_exporter:v1.3.5-alpine
    storage:
      persistentVolumeClaim:
        metadata:
          name: redisfailover-persistent-data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
  auth:
    secretPath: redis-auth
```
```
kubectl apply -f enable-exporter.yaml -n redis-system
```
	
### 4. 对接prometheus

- pod-monitor.yaml

	```
	apiVersion: monitoring.coreos.com/v1  
    kind: PodMonitor
    metadata:
      name: redis
      labels:
        release: prometheus-community
    spec:
      podMetricsEndpoints:
        - interval: 15s
          port: metrics
      selector:
        matchLabels:
          app.kubernetes.io/component: redis
      namespaceSelector:
        any: true
	
	```
	```
	kubectl apply -f pod-monitor.yaml -n redis-system
	```
	
### 5. 下载redis的监控模板，在grafana中创建

 - https://grafana.com/grafana/dashboards/763
