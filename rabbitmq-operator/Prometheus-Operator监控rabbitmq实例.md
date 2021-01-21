### Prometheus监控rabbitmq


### 先决条件

- [rabbitmq-cluster-operator 部署](https://github.com/rabbitmq/cluster-operator)

- [prometheus-operator部署](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)


### 启动k8s dashboard

- 运行dashboard
	
	```
	kubectl proxy
	```

- 访问地址

	http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

- 查看token

	```
	TOKEN=$(kubectl -n kube-system describe secret default| awk '$1=="token:"{print $2}')
	kubectl config set-credentials docker-for-desktop --token="${TOKEN}"
	echo $TOKEN
	
	```
	
### 启动prometheus

- 使用port-forward转发grafana服务端口，提供访问入口

	```
	kubectl port-forward svc/prometheus-community-grafana 3000:80 -n monitoring
	
	```

- 查看 grafana 登录用户密码
	
	```
	kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-user:"|awk '{print $2}'|base64 -d
	kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-password:"|awk '{print $2}'|base64 -d
	
	```
	
	即：
	
	```
	admin/prom-operator
	
	```

- 通过浏览器访问grafana http://127.0.0.1:3000
- 使用port-forward转发prometheus服务端口，提供访问入口

    ```
     kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring
      
    ```

- 通过浏览器访问prometheus http://127.0.0.1:9090

###  创建PodMonitor实例，名为rabbitmq-podmonitor.yaml

```
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: rabbitmq
  #为了让prometheus发现rabbitmq，注意prometheus-community值与helm 安装prometheus时创建的名字一致。否则无效。
  labels:
    release: prometheus-community
spec:
  podMetricsEndpoints:
  - interval: 15s
    port: prometheus
  selector:
    matchLabels:
      app.kubernetes.io/component: rabbitmq
  namespaceSelector:
    any: true
```

这定义了PodMonitor资源，这是配置RabbitMQ集群的自动发现所必需的。

接下来，通过运行来应用PodMonitor资源

```
kubectl apply -f rabbitmq-podmonitor.yaml
```

#### 权限问题

可以在任何命名空间中创建PodMonitor，只要Prometheus Operator有权找到它即可.如果prometheus中没有 RabbitMQ 集群，则可能需要调整prometheus的权限。 

注意：如果是使用helm安装的prometheus，则不需要更改权限.

创建一个 prometheus-roles.yaml

```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: monitoring

```

kubectl 运行

```
kubectl apply -f prometheus-roles.yaml
```

### 下载官方rabbitmq对应的grafana模板,无需改动就能有数据

https://grafana.com/api/dashboards/10991/revisions/8/download


### 参考资料

[官方文档](https://www.rabbitmq.com/kubernetes/operator/operator-monitoring.html)
[配置监控grafana](https://www.rabbitmq.com/prometheus.html#grafana-configuration)