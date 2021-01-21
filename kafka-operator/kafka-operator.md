# kafka and zk 
在k8s集群上使用kafka的operator 来安装kafka集群。

欲搭建kafka 环境，需要先搭建kafka的依赖的环境。

依赖如下：

- cert-manager
	- **0.15.x:** Kafka operator 0.8.x and newer supports cert-manager 0.15.x
	- **0.10.x:** Kafka operator 0.7.x supports cert-manager 0.10.x
- zookeeper
- Prometheus


## 1、Install cert-manager
由于网络问题，建议使用yaml方式安装。默认部署到 namespace 为`cert-manager`下

### 1.1 使用yaml 方式安装（推荐）
```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.yaml

```

### 1.2 使用helm 方式安装（不推荐）
```
# Add the jetstack helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager into the cluster
# Using helm3
helm install cert-manager --namespace cert-manager --create-namespace --version v0.15.1 jetstack/cert-manager
# Using previous versions of helm
helm install --name cert-manager --namespace cert-manager --version v0.15.1 jetstack/cert-manager
  
# Install the CustomResourceDefinitions
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.crds.yaml
```


## 2、Install Zookeeper 

这里使用 `Pravega’s Zookeeper Operator` 来搭建zk集群。也有两种方式部署 zk operator。

这里仍然推荐使用yaml 方式。[参考文档](https://github.com/pravega/zookeeper-operator)

### 2.1 使用helm 方式(不推荐)
```
# Deprecated, please use Pravega's helm chart
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com/
# Using helm3
helm install zookeeper-operator --namespace=zookeeper --create-namespace banzaicloud-stable/zookeeper-operator
# Using previous versions of helm
# Deprecated, please use Pravega's helm chart
helm install --name zookeeper-operator --namespace=zookeeper banzaicloud-stable/zookeeper-operator
kubectl create --namespace zookeeper -f - <<EOF
apiVersion: zookeeper.pravega.io/v1beta1
kind: ZookeeperCluster
metadata:
  name: zookeeper
  namespace: zookeeper
spec:
  replicas: 3
EOF
```

### 2.2 使用yaml 方式（推荐）

首先下载 `pravega/zookeeper-operator`项目 如`git clone git@github.com:pravega/zookeeper-operator.git`，然后打开terminal，切换到  zookeeper-operator目录

建议 把 zk 部署到 `zookeeper`命名空间下。

#### 2.2.1 安装注册定义资源(crd)

```
kubectl apply -f deploy/crds/zookeeper.pravega.io_zookeeperclusters_crd.yaml
```

#### 2.2.2 创建独立的命名空间

```
kubectl create namespace zookeeper
```

#### 2.2.3 安装权限控制(rbac)

```
kubectl create -f deploy/default_ns/rbac.yaml -n zookeeper
```

#### 2.2.4 部署zk-operator
```
kubectl create -f deploy/default_ns/operator.yaml -n zookeeper
```

#### 2.2.5 查看 zk-operator运行状态
```
$ kubectl get deploy -n zookeeper

NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
zookeeper-operator   1         1         1            1           12m
```

#### 2.2.6 部署zk-cluster集群
建立 `zk.yaml`文件。这里是搭建3-node的zk集群

```
apiVersion: "zookeeper.pravega.io/v1beta1"
kind: "ZookeeperCluster"
metadata:
  name: "zookeeper"
spec:
  replicas: 3

```

**命令执行**

```
$ kubectl create -f zk.yaml
```

**查看集群运行状态1：**

```
kubectl get zk -n zookeeper

NAME        REPLICAS   READY REPLICAS    VERSION   DESIRED VERSION   INTERNAL ENDPOINT    EXTERNAL ENDPOINT   AGE
zookeeper   3          3                 0.2.8     0.2.8             10.100.200.18:2181   N/A                 94s
```

**查看集群运行状态2：**

```
$ kubectl get all -l app=zookeeper -n zookeeper

NAME                     DESIRED   CURRENT   AGE
statefulsets/zookeeper   3         3         2m

NAME             READY     STATUS    RESTARTS   AGE
po/zookeeper-0   1/1       Running   0          2m
po/zookeeper-1   1/1       Running   0          1m
po/zookeeper-2   1/1       Running   0          1m

NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
svc/zookeeper-client     ClusterIP   10.31.243.173   <none>        2181/TCP            2m
svc/zookeeper-headless   ClusterIP   None            <none>        2888/TCP,3888/TCP   2m
```


### 2.3 验证 zk服务可用
#### 2.3.1 使用zk的客户端命令连接

需要下载zk的安装包，解压并进入到其bin目录

```
./zkCli -server ip:2181 

或者 svc

# 直接暴露到本地端口
kubectl port-forward svc/zookeeper-client 2181:2181 -n zookeeper
# 连接测试
./zkCli.sh -server  localhost:2181


```

#### 2.3.2 使用zk-web 验证

基于镜像[`tobilg/zookeeper-webui:latest`](https://hub.docker.com/r/tobilg/zookeeper-webui),使用yaml `zk-web.yaml`部署zk-web验证。访问入口`http://localhost:8080`

```
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
          image: 'tobilg/zookeeper-webui:latest'
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

```

**运行命令:**

```
kubectl apply -f zk-web.yaml -n zookeeper
```

访问入口`http://localhost:8080`


## 3、 install prometheus-operator

有两种方式安装。

[参考文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)

### 3.1 install with helm 方式


#### 3.1.1  添加 repo, 更新repo 信息

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

#### 3.1.2  查看所有可配置选项的详细注释

```
helm show values prometheus-community/kube-prometheus-stack
```

#### 3.1.3  部署prometheus-operator

mac 环境node-exporter因不存在`/var/log/pods`目录运行失败，所以禁用

```
kubectl create namespace monitoring
helm install prometheus-community prometheus-community/kube-prometheus-stack -n  monitoring \
--set nodeExporter.enabled=false
```

查看 helm 部署的 chart

```
helm ls -n monitoring
```

查看 prometheus-operator 相关pod 状态

```
kubectl get pod -n monitoring
```

#### 3.1.4 使用port-forward转发grafana服务端口，提供访问入口

```
kubectl port-forward svc/prometheus-community-grafana 3000:80 -n monitoring
```

查看 grafana 登录用户密码

```
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-user:"|awk '{print $2}'|base64 -d
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-password:"|awk '{print $2}'|base64 -d
```

通过访问 http://127.0.0.1:3000 访问grafana


#### 3.1.5 卸载 prometheus-community

```
helm uninstall prometheus-community -n monitoring
```


## 4. install kafka-operator


这里也有两种方式安装。这里采用yaml 的方式。

### 4.1 install with helm  方式


### 4.2 使用yaml方式
先拉取代码到本地。如：`git clone git@github.com:banzaicloud/kafka-operator.git`

切换目录到 `kafka-operator/config`

#### 4.2.1 建立 `kafka`命名空间
```
kubectl create namespace kafka
```

#### 4.2.2 注册定义资源(crd)
```
kubectl apply -f base/crds/kafka.banzaicloud.io_kafkaclusters.yaml 
kubectl apply -f base/crds/kafka.banzaicloud.io_kafkatopics.yaml 
kubectl apply -f base/crds/kafka.banzaicloud.io_kafkausers.yaml 
```


#### 4.2.3 安装权限控制(rbac)
```
kubectl apply -f  base/rbac/role.yaml 
kubectl apply -f  base/rbac/role_binding.yaml 
kubectl apply -f  base/rbac/leader_election_role.yaml 
kubectl apply -f  base/rbac/leader_election_role_binding.yaml 
```
#### 4.2.4 安装 operator的controller manager
这里需要注意:

- 拉下来的代码是没有配置 cert配置的。需要挂载，

```
containers:
      ....
        volumeMounts:
        - mountPath: /etc/webhook/certs
          name: cert
          readOnly: true
      .......
      terminationGracePeriodSeconds: 10
      volumes:
      - name: cert
        secret:
          defaultMode: 420
          secretName: webhook-server-cert
```

- 修改operator 镜像，默认是latest。修改为最新版本 `ghcr.io/banzaicloud/kafka-operator:v0.14.0`


**安装manager**

```
kubectl apply -f base/manager/manager.yaml

```


#### 4.2.5 安装webhook

```
kubectl apply -f base/alertmanager/service.yaml
kubectl apply -f base/webhook/manifests.yaml
kubectl apply -f base/webhook/service.yaml
```

#### 4.2.6 安装部署 kafka集群

核对 `config/samples/simplekafkacluster.yaml` 文件，如果zk 安装在 命名空间`zookeeper`下，可以忽略核对

- 指定namespace 为kafka 如：`namespace: kafka`
- 核对zk的连接地址endpoint。 


**执行安装**

```
kubectl create -n kafka -f config/samples/simplekafkacluster.yaml
```

若是对接prometheus 执行

```
kubectl create -n default -f config/samples/kafkacluster-prometheus.yaml
```

#### 4.2.7 验证kafka

配置 `kafka-cruisecontrol-svc:8090` 或者打通容器和本地的网络[详情](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

然后访问：`http://10.102.231.117:8090/#/` 可以查看kafka的监控状态



## 参考文档
- [banzaicloud/kafka-operator 源码](https://github.com/banzaicloud/kafka-operator)
- [kafka-operator 安装文档](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)
- [pravega/zookeeper-operator 源码及docs](https://github.com/pravega/zookeeper-operator)
- [prometheus-operator文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)
- [基础环境与网络](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

