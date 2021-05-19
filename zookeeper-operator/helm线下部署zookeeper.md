# helm线下部署zookeeper

## 下面镜像推送到私有仓库

```
docker.mirrors.ustc.edu.cn/pravega/zookeeper-operator:0.2.10
docker.mirrors.ustc.edu.cn/lachlanevenson/k8s-kubectl:v1.16.10
docker.mirrors.ustc.edu.cn/pravega/zookeeper:0.2.10
docker.mirrors.ustc.edu.cn/tobilg/zookeeper-webui:latest
```

## 新建namespace
```
kubectl create namespace zookeeper
```

## 部署zookeeper-operator

```
helm repo add pravega https://charts.pravega.io
helm repo update
# 下载最新chart包
helm pull pravega/zookeeper-operator --version=0.2.10

helm install pravega zookeeper-operator-0.2.10.tgz -n zookeeper \
--set image.repository=registry.hisun.netwarps.com/pravega/zookeeper-operator \
--set hooks.image.repository=registry.hisun.netwarps.com/lachlanevenson/k8s-kubectl
```

查看 pod

```
kubectl get pod -n zookeeper
```

## 部署zookeeper

安装单机zookeeper

```
# 下载最新chart包
helm pull pravega/zookeeper --version=0.2.10
helm install kafka-zk zookeeper-0.2.10.tgz -n zookeeper \
--set replicas=3 \
--set image.repository=registry.hisun.netwarps.com/pravega/zookeeper \
--set hooks.image.repository=registry.hisun.netwarps.com/lachlanevenson/k8s-kubectl \
--set persistence.storageClassName=local-path
```
查看 pod

```
kubectl get pod -n zookeeper
```

部署 zookeeper web ui

创建 部署yaml

```
# 根据环境修改应用域名后缀
APP_DOMAIN=apps164103.hisun.k8s

cat<<EOF > zkweb.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: zkweb
  name: zkweb
  namespace: zookeeper
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: zkweb
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: zkweb
    spec:
      containers:
        - env:
            - name: ZK_DEFAULT_NODE
              value: 'zookeeper-client:2181'
          image: 'registry.hisun.netwarps.com/tobilg/zookeeper-webui:latest'
          imagePullPolicy: Always
          securityContext:
            privileged: true
          name: zkweb
          ports:
            - containerPort: 8080
              name: http
              protocol: TCP
          resources: {}
          terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: zkweb
  namespace: zookeeper
  labels:
    app: zkweb
spec:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 8080
      targetPort: http
  selector:
    app: zkweb
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: zkweb-ingress
  namespace: zookeeper
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: zkweb.${APP_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: zkweb
            port:
              number: 8080
EOF
```
执行部署

```
kubectl apply -f zkweb.yaml -n zookeeper
```

查看 pod

```
kubectl get pod -n zookeeper
```

查看 zookeeper svc 名称

```
kubectl get svc -n zookeeper

kafka-zk-zookeeper-client     ClusterIP   10.110.60.213    <none>        2181/TCP                              23m
kafka-zk-zookeeper-headless   ClusterIP   None             <none>        2181/TCP,2888/TCP,3888/TCP,7000/TCP   23m
zkweb                         ClusterIP   10.105.215.100   <none>        8080/TCP                              5m14s
```

解析 apps164103.hisun.k8s 并访问

```
zkweb.apps164103.hisun.k8s
```

首页输入

```
kafka-zk-zookeeper-client.zookeeper.svc:2181
```

## 收集 zookeeper metrics 数据

创建`zookeeper-podMonitor.yaml`

```
cat>zookeeper-podMonitor.yaml<<EOF
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: zookeeper
  #为了让prometheus发现zookeeper，注意prometheus-community值与helm 安装prometheus时创建的名字一致。否则无效。
  labels:
    release: prometheus-community
spec:
  podMetricsEndpoints:
  - interval: 15s
    port: metrics
  selector:
    matchLabels:
      app: kafka-zk-zookeeper
  namespaceSelector:
    any: true
EOF
```

执行创建 podMonitor

```
kubectl apply -f zookeeper-podMonitor.yaml -n zookeeper
```

## 导入 grafana 模板

打开 grafana 页面导入 [Zookeeper-by-Prometheus.json](./grafana-dashboards/Zookeeper-by-Prometheus.json)

## 参考

https://github.com/paradeum-team/operator-env/blob/main/kafka-operator/kafka-operator.md

https://github.com/pravega/zookeeper-operator

https://grafana.com/grafana/dashboards/10465