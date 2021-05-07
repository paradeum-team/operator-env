## Mysql-Operator部署


### Helm安装Mysql-Operator
		
#### 新增repo

	helm repo add presslabs https://presslabs.github.io/charts

#### 安装mysql-operator

	helm install presslabs/mysql-operator --name mysql-operator

### 部署Mysql服务

#### 创建秘钥

 	kubectl apply -f https://raw.githubusercontent.com/presslabs/mysql-operator/master/examples/example-cluster-secret.yaml

#### 创建mysql服务集群

	kubectl apply -f https://raw.githubusercontent.com/presslabs/mysql-operator/master/examples/example-cluster.yaml
	
#### 依赖的镜像

#### msyql 
	
	quay.io/presslabs/mysql-operator-sidecar:0.4.0
	prom/mysqld-exporter:v0.11.0
	
#### operator

	quay.io/presslabs/mysql-operator:0.4.0
	quay.io/presslabs/mysql-operator-orchestrator:0.4.0		
### 监控


#### 发布podMonitor

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

#### mysql grafana模板

https://grafana.com/grafana/dashboards/7362

#### 参考地址

[mysql-operator](https://github.com/presslabs/mysql-operator)