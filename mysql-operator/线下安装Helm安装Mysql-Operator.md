### 线下安装Helm安装Mysql-Operator

### 1. 下载mysql-operator chart

[mysql-operator-0.4.0.tgz](https://pnode.solarfs.io/dn/file/0d0e58bc6775b711f84637c699836031/mysql-operator-0.4.0.tgz)

- 解压tgz，修改value.yaml，更改镜像

	```
	tar -zxvf mysql-operator-0.4.0.tgz
	```
	修改value.yaml,把镜像推到内部镜像仓库，默认推到了registry.hisun.netwarps.com

	
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

- secret.yaml 用来创建mysql的root密码

	```
	apiVersion: v1
	kind: Secret
	metadata:
	  name: mysql-secret
	type: Opaque
	data:
	  # root password is required to be specified
	  ROOT_PASSWORD: MTIzNDU2
	
	```
	
- cluster-mysql.yaml

	```
	apiVersion: mysql.presslabs.org/v1alpha1
	kind: MysqlCluster
	metadata:
	  name: mysql-cluster
	spec:
	  replicas: 2
	  secretName: mysql-secret
	
	```
    使用 kubectl apply -f mysql.yaml -n mysql-system进行部署，该yaml文档在kont自动化部署目录中，相关内容请根据实际情况修改
	
- 持久化三种方式

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
