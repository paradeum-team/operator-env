# Rabbitmq-operator

### 环境准备

- Kubernetes 1.17或以上
- RabbitMQ image 3.8.8+

### 部署 rabbitmq cluster-operator
- 下载部署文件[cluster-operator.yml](https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml)
- 执行 

		kubectl apply -f cluster-operator.yml

### 部署 rabbitmq 服务
- 下载部署文件 [rabbitmq.yaml](https://raw.githubusercontent.com/rabbitmq/cluster-operator/main/docs/examples/hello-world/rabbitmq.yaml)
- 执行
	
		kubectl apply -f rabbitmq.yaml

### 验证服务可用性

```
kubectl get customresourcedefinitions.apiextensions.k8s.io

# NAME                                   CREATED AT
# rabbitmqclusters.rabbitmq.com               2021-01-14T09:15:45Z
```

```
kubectl get all -l app.kubernetes.io/name=hello-world

NAME                       READY   STATUS    RESTARTS   AGE
pod/hello-world-server-0   1/1     Running   0          4d17h

NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                        AGE
service/hello-world         ClusterIP   10.110.240.49   <none>        15672/TCP,5672/TCP             4d17h
service/hello-world-nodes   ClusterIP   None            <none>        4369/TCP,25672/TCP             4d17h
service/rabbitmq            ClusterIP   None            <none>        5672/TCP,15692/TCP,15672/TCP   16h

NAME                                  READY   AGE
statefulset.apps/hello-world-server   1/1     4d17h
```

## 问题
- rabbitmq 官方镜像下载不了

	因为众所周知的问题，需要设置 docker 的 mirror, 
	
	- 设置 `Preferences -> Docker Engine `

			{
			  "debug": true,
			  "experimental": false,
			  "registry-mirrors": [
			    "https://registry.docker-cn.com"
			  ]
			}
	- 查询镜像地址

			kubectl edit statefulset/rabbitmq-cluster-server
- 启动 node 调度失败
	- 发现 pod 启动 pending,发现报内存问题 `kubectl describe pod rabbitmq-cluster-server-0 `，报 `Insufficient memory` 内存不足，mac docker 的内存不足
	- 设置 `Preferences -> Resources`，调节 4GB

### 文档参考

- 使用文档： https://www.rabbitmq.com/kubernetes/operator/using-operator.html
- 部署文档： https://github.com/rabbitmq/cluster-operator
- 监控MQ: https://www.rabbitmq.com/kubernetes/operator/operator-monitoring.html