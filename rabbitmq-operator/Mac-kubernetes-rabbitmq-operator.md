# Rabbitmq-operator

### 环境准备

- Kubernetes 1.17或以上
- RabbitMQ image 3.8.8+

### 部署rabbitmq cluster-operator

- 下载文件，[cluster-operator.yml](https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml)
- 执行 kubectl apply -f cluster-operator.yml

### 部署rabbitmq服务

kubectl apply -f https://raw.githubusercontent.com/rabbitmq/cluster-operator/main/docs/examples/hello-world/rabbitmq.yaml

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


### 文档参考

- 使用文档： https://www.rabbitmq.com/kubernetes/operator/using-operator.html
- 部署文档： https://github.com/rabbitmq/cluster-operator
- 监控MQ: https://www.rabbitmq.com/kubernetes/operator/operator-monitoring.html