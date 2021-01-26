# 说明
在k8s集群上使用kafka的operator 来安装kafka集群。

欲搭建kafka 环境，需要先搭建kafka的依赖的环境。

依赖如下：

- cert-manager
	- **0.15.x:** Kafka operator 0.8.x and newer supports cert-manager 0.15.x
	- **0.10.x:** Kafka operator 0.7.x supports cert-manager 0.10.x
- zookeeper
- Prometheus

# Install Zookeeper 

这里使用 `Pravega’s Zookeeper Operator` 来搭建zk集群。也有两种方式部署 zk operator。

这里仍然推荐使用yaml 方式。[参考文档](https://github.com/pravega/zookeeper-operator)

## 1.1 使用helm 方式(默认安装)
### 1.1.1 使用新镜像默认配置

```
 helm repo add pravega https://charts.pravega.io
 helm repo update
# Using helm3
helm install zookeeper-operator --namespace=zookeeper --create-namespace pravega/zookeeper-operator

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

### 1.1.2 不推荐，这个镜像比较旧

这里参考kafka-operator，没有验证helm

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
 



## 1.2 使用 helm 安装 (推荐一)
基于本机环境已有镜像，修改values.yaml 和离线chart，转移线上环境安装。

### 1.2.1 添加 repo，更新repo信息

```
$ helm repo add pravega https://charts.pravega.io
$ helm repo update
```

### 1.2.2 查看所有可配置选项的详细注释

```
helm show values pravega/zookeeper-operator
```
或 访问github 地址查看

```
https://github.com/pravega/zookeeper-operator/blob/master/charts/zookeeper-operator/values.yaml
```

### 1.2.3 下载相关镜像到 私有仓库

镜像地址从下面values.yaml中查找 repository

```
https://github.com/pravega/zookeeper-operator/blob/master/charts/zookeeper-operator/values.yaml

https://github.com/pravega/zookeeper-operator/blob/master/charts/zookeeper/values.yaml
```

pravega/zookeeper-operator:0.2.9
lachlanevenson/k8s-kubectl:v1.16.10
pravega/zookeeper:0.2.9
tobilg/zookeeper-webui:latest

### 1.2.4 下载chart
```
helm pull pravega/zookeeper-operator --version 0.2.9
```

### 1.2.5 创建 namespace
```
kubectl create namespace zookeeper
```

### 1.2.6 创建values.yaml文件
修改自定义的yaml文件：

todo : 在原有的values.yaml 上改，

- 修改zk-operator 的helm 属性文件

```
# 域名后缀
domain="apps164103.hisun.local"
# 私有镜像仓库地址
repository="registry.hisun.netwarps.com"

cat <<EOF > zookeeper-operator-stack-values.yaml 
image:
  repository: ${repository}/zookeeper/zookeeper-operator
  tag: 0.2.9
  pullPolicy: IfNotPresent
hooks:
  backoffLimit: 10
  image:
    repository: ${repository}/lachlanevenson/k8s-kubectl
    tag: v1.16.10
EOF
```

- 修改zookeeper 的helm属性文件 或者 **扩缩更新**

```
# 域名后缀
domain="apps164103.hisun.local"
# 私有镜像仓库地址
repository="registry.hisun.netwarps.com"

cat <<EOF > zookeeper-stack-values.yaml 
replicas: 3
image:
  repository: ${repository}/zookeeper/zookeeper
  tag: 0.2.9
  pullPolicy: IfNotPresent
hooks:
  backoffLimit: 10
  image:
    repository: ${repository}/lachlanevenson/k8s-kubectl
    tag: v1.16.10
EOF
```

### 1.2.7 执行部署
使用默认的安装包
```
$ helm install zookeeper-operator pravega/zookeeper-operator --version=0.2.9 -n zookeeper
```

使用自定配置和离线的chart包安装

```
eg:

helm install zookeeper-operator zookeeper-operator-stack-0.2.9.tgz -f zookeeper-operator-stack-values.yaml -n  zookeeper

helm install zookeeper-operator zookeeper-operator-stack-0.2.9.tgz -f zookeeper-stack-values.yaml -n  zookeeper
```


### 1.2.8 更新已部署服务
可以下载新版本 charts 包，或修改 values.yaml 进行更新

helm upgrade 语法

```
Usage:
  helm upgrade [RELEASE] [CHART] [flags]
```

使用修改后的values.yaml 或者 charts包

```
helm upgrade zookeeper-operator zookeeper-operator-stack-0.2.9.tgz -f zookeeper-operator-stack-values.yaml -n  zookeeper
```

----




## 1.3 使用yaml 方式（推荐）

首先下载 `pravega/zookeeper-operator`项目 如`git clone https://github.com/pravega/zookeeper-operator.git`，然后打开terminal，切换到  zookeeper-operator目录

建议 把 zk 部署到 `zookeeper`命名空间下。

### 1.3.1 安装注册定义资源(crd)

```
kubectl apply -f deploy/crds/zookeeper.pravega.io_zookeeperclusters_crd.yaml
```

### 1.3.2 创建独立的命名空间

```
kubectl create namespace zookeeper
```

### 1.3.3 安装权限控制(rbac)

```
kubectl create -f deploy/default_ns/rbac.yaml -n zookeeper
```

### 1.3.4 部署zk-operator
```
kubectl create -f deploy/default_ns/operator.yaml -n zookeeper
```

### 1.3.5 查看 zk-operator运行状态
```
$ kubectl get deploy -n zookeeper

NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
zookeeper-operator   1         1         1            1           12m
```

### 1.3.6 部署zk-cluster集群
建立 `zk.yaml`文件。这里是搭建3-node的zk集群

```
apiVersion: "zookeeper.pravega.io/v1beta1"
kind: "ZookeeperCluster"
metadata:
  name: "zookeeper"
  namespace: "zookeeper"
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
### 1.3.7 zk扩缩
修改下面配置项目`replicas: 5` 即可，重新发布
```
apiVersion: "zookeeper.pravega.io/v1beta1"
kind: "ZookeeperCluster"
metadata:
  name: "zookeeper"
  namespace: "zookeeper"
spec:
  replicas: 3
```

**命令执行**

```
$ kubectl create -f zk.yaml
```




## 1.4 验证 zk服务可用
### 1.4.1 使用zk的客户端命令连接

需要下载zk的安装包，解压并进入到其bin目录

```
./zkCli -server ip:2181 

或者 svc

# 直接暴露到本地端口
kubectl port-forward svc/zookeeper-client 2181:2181 -n zookeeper
# 连接测试
./zkCli.sh -server  localhost:2181


```

### 1.4.2 使用zk-web 验证

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

**端口映射转发**

```
kubectl port-forward svc/zkweb 8080:8080 -n zookeeper
```


访问入口`http://localhost:8080`

打开页面后输入 svc 的endpoint。eg :`zookeeper-client.zookeeper:2181`


## 参考文档
- [banzaicloud/kafka-operator 源码](https://github.com/banzaicloud/kafka-operator)
- [kafka-operator 安装文档](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)
- [pravega/zookeeper-operator 源码及docs](https://github.com/pravega/zookeeper-operator)
- [prometheus-operator文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)
- [基础环境与网络](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

