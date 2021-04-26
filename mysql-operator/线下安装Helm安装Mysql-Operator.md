### 线下安装Helm安装Mysql-Operator

### 1. 下载mysql-operator chart

[mysql-operator-0.4.0.tgz](https://pnode.solarfs.io/dn/file/0d0e58bc6775b711f84637c699836031/mysql-operator-0.4.0.tgz)

- 解压tgz，修改value.yaml，更改镜像

	```
	tar -zxvf mysql-operator-0.4.0.tgz
	```
	修改value.yaml  
	
	- 把镜像推到内部镜像仓库，默认推到了registry.hisun.netwarps.com   
	
	- ApplyMySQLPromotionAfterMasterFailover参数修改成true

	
### 2. helm部署mysql-operator

- 创建 namespace 
		
	```	
	 kubectl create namespace mysql-system
	
	```
	
- 部署operator

	```
	helm install mysql-operator mysql-operator -n mysql-system
	
	```
   
	
### 3. 部署mysql服务	

- 编辑secret.yaml 用来创建mysql的root密码

    ```
    kuberctl apply -f  secret.yaml 
    ```
    
	```
	apiVersion: v1
	kind: Secret
	metadata:
	  name: my-secret
	  namespace: mysql-system
	type: Opaque
	data:
	  # root password is required to be specified
	  ROOT_PASSWORD: MTIzNDU2
	
	```
	
- 编辑cluster-mysql.yaml（默认带pvc发布）

    ```
    kuberctl apply -f cluster-mysql.yaml
    ```
        
	```
	apiVersion: mysql.presslabs.org/v1alpha1
	kind: MysqlCluster
	metadata:
	  name: mysql-cluster
	  namespace: mysql-system
	spec:
	  replicas: 2
	  secretName: my-secret
	  volumeSpec:
	    persistentVolumeClaim:
	      accessModes: ["ReadWriteOnce"]
	      resources:
	        requests: 
	          storage: 1Gi
	```
	
- 持久化三种方式(任选一种即可，上面部署了持久化，下面就不用部署了)

  - PVC
  
	```
    apiVersion: mysql.presslabs.org/v1alpha1
    kind: MysqlCluster
    metadata:
      name: my-cluster
    spec:
      replicas: 2
      secretName: my-secret
      volumeSpec:
        persistentVolumeClaim:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi
	```
	
  - HostPath
  
    ```
    apiVersion: mysql.presslabs.org/v1alpha1
    kind: MysqlCluster
    metadata:
      name: my-cluster
    spec:
      replicas: 2
      secretName: my-secret
      volumeSpec:
        hostPath:
          path: /path/to/host/dir/
    ```
    
  - EmptyDir
		
	```
    apiVersion: mysql.presslabs.org/v1alpha1
    kind: MysqlCluster
    metadata:
      name: my-cluster
    spec:
      replicas: 2
      secretName: my-secret
      volumeSpec:
        hostPath:
          emptyDir: {}
	```
  
### 4. 对接prometheus

对接prometheus前请先确认k8s环境是否部署了prometheus，[参看部署文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2prometheus-operator.md)
- pod-monitor.yaml
	
	```
	apiVersion: monitoring.coreos.com/v1
	kind: PodMonitor
	metadata:
	  name: mysql
	  labels:
	    release: prometheus-community
	spec:
	  podMetricsEndpoints:
	  - interval: 15s
	    port: prometheus
	  selector:
	    matchLabels:
	      app.kubernetes.io/component: database
	  namespaceSelector:
	    any: true
	```
	
### 5. 下载msyql的监控模板，在grafana中创建

 - https://grafana.com/grafana/dashboards/7362
