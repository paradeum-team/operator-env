# 说明 
在k8s集群上使用kafka的operator 来安装kafka集群。

欲搭建kafka 环境，需要先搭建kafka的依赖的环境。

依赖如下：

- cert-manager
	- **0.15.x:** Kafka operator 0.8.x and newer supports cert-manager 0.15.x
	- **0.10.x:** Kafka operator 0.7.x supports cert-manager 0.10.x
- zookeeper
- Prometheus

# install kafka-operator


这里也有两种方式安装。

这里kafka的部署，其operator 可以使用helm 方式部署，但是kafka实例却没有对应的helm ，需要按照yaml发布部署，也可以按照zk的操作写一个kafka的helm 部署。

## 1.1 install with helm (默认配置)
```
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com/
# Using helm3
helm install kafka-operator --namespace=kafka --create-namespace banzaicloud-stable/kafka-operator
# Using previous versions of helm
helm install --name=kafka-operator --namespace=kafka banzaicloud-stable/kafka-operator
# Add your zookeeper svc name to the configuration
kubectl create -n kafka -f config/samples/simplekafkacluster.yaml
# If prometheus operator installed create the ServiceMonitors
kubectl create -n kafka -f config/samples/kafkacluster-prometheus.yaml
```

## 1.2 install with helm(自定义)
使用自定义配置 values.yaml 和离线chart 安装

### 1.2.1 安装 cert-manager & zookeeper
### 1.2.2 安装kafka-operator对应的crd资源
```
kubectl apply --validate=false -f https://github.com/banzaicloud/kafka-operator/releases/download/v0.12.3/kafka-operator.crds.yaml
```

### 1.2.3 添加 repo, 更新repo 信息
```
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
helm repo update
```


### 1.2.4 下载相关镜像到私有仓库
```
https://github.com/banzaicloud/kafka-operator/blob/master/charts/kafka-operator/values.yaml
```

iamges list:

```
ghcr.io/banzaicloud/kafka-operator:v0.14.0
gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0
ghcr.io/banzaicloud/jmx-javaagent:0.14.0
ghcr.io/banzaicloud/kafka:2.13-2.6.0-bzc.1
```

### 1.2.4 下载chart
```
helm pull banzaicloud-stable/kafka-operator --version v0.14.0

```

### 1.2.5 自定义values.yaml
todo

```
# 域名后缀
domain="apps164103.hisun.local"
# 私有镜像仓库地址
repository="registry.hisun.netwarps.com"

cat <<EOF > kafka-operator-stack-values.yaml 
operator:
  annotations: {}
  image:
    repository: ghcr.io/banzaicloud/kafka-operator
    tag: v0.14.0
    pullPolicy: IfNotPresent
certManager:
  namespace: "cert-manager"
  enabled: true
 
prometheusMetrics:
  enabled: true
  authProxy:
    enabled: true
    image:
      repository: gcr.io/kubebuilder/kube-rbac-proxy
      tag: v0.5.0
      pullPolicy: IfNotPresent
    serviceAccount:
      create: true
      name: kafka-operator-authproxy
EOF

```

### 1.2.6 安装
- 无证书

```
$ helm install kafka-operator  --namespace=kafka  --create-namespace registry.hisun.netwarps.com/banzaicloud-stable/kafka-operator
```

- 有证书
```
$ helm install kafka-operator --set certManager.namespace=<your cert manager namespace> --namespace=kafka  --create-namespace registry.hisun.netwarps.com/banzaicloud-stable/kafka-operator
```

或者

```
helm install kafka-operator kafka-operator-v0.14.0.tgz kafka-operator-stack-values.yaml -n kafka
```

### 1.2.7 更新升级

```
helm upgrade kafka-operator --set crd.enabled=true --namespace=kafka registry.hisun.netwarps.com/banzaicloud-stable/kafka-operator

```

### 1.2.8 卸载
```
 helm delete  kafka-operator -n kafka
```


## 1.3 使用yaml方式
先拉取代码到本地。如：`git clone https://github.com/banzaicloud/kafka-operator.git`

切换目录到 `kafka-operator/config`

### 1.3.1 建立 `kafka`命名空间
```
kubectl create namespace kafka
```

### 1.3.2 注册定义资源(crd)
```
kubectl apply -f base/crds/kafka.banzaicloud.io_kafkaclusters.yaml 
kubectl apply -f base/crds/kafka.banzaicloud.io_kafkatopics.yaml 
kubectl apply -f base/crds/kafka.banzaicloud.io_kafkausers.yaml 
```


### 1.3.3 安装权限控制(rbac)
```
kubectl apply -f  base/rbac/role.yaml 
kubectl apply -f  base/rbac/role_binding.yaml 
kubectl apply -f  base/rbac/leader_election_role.yaml 
kubectl apply -f  base/rbac/leader_election_role_binding.yaml 
```
### 1.3.4 安装 secret
因没有弄清楚 cert-manager 怎么使用，这里建立一个secret。部署需要的tls.crt配置

修改文件 `config/overlays/basic/certificate.yaml`,把其 `namespace：system` 更改成`namespace:kafka`
 
 然后执行：
 
 ```
 kubectl apply -f config/overlays/basic/certificate.yaml -n kafka
 ```
 



### 1.3.5 安装 operator的controller manager
这里需要注意:

- 把命名空间 system 修改为 kafka
- 拉下来的代码是没有配置 cert配置的。需要挂载，

```
metadata:
  name: controller-manager
  namespace: kafka
spec:
.....
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


### 1.3.5 安装webhook

```
kubectl apply -f base/alertmanager/service.yaml
kubectl apply -f base/webhook/manifests.yaml
kubectl apply -f base/webhook/service.yaml
```

### 1.3.6 安装部署 kafka集群

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

### 1.3.7 kafka集群扩缩

修改发布模板 `config/samples/simplekafkacluster.yaml` 修改其中的

```
brokers:
    - id: 0
      brokerConfigGroup: "default"
    - id: 1
      brokerConfigGroup: "default"
    - id: 2
      brokerConfigGroup: "default"
    - id: 3
      brokerConfigGroup: "default"
    - id: 4
      brokerConfigGroup: "default"
```

**重新发布**

```
kubectl create -n kafka -f config/samples/simplekafkacluster.yaml
```



### 1.3.8 验证kafka

配置 `kafka-cruisecontrol-svc:8090` 或者打通容器和本地的网络[详情](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

然后访问：`http://10.102.231.117:8090/#/` 可以查看kafka的监控状态

或者

```
kubectl port-forward svc/kafka-cruisecontrol-svc 8090:8090 -n kafka
```

然后访问：`http://localhost:8090/#/` 可以查看kafka的监控状态





## 参考文档
- [banzaicloud/kafka-operator 源码](https://github.com/banzaicloud/kafka-operator)
- [kafka-operator 安装文档](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)
- [pravega/zookeeper-operator 源码及docs](https://github.com/pravega/zookeeper-operator)
- [prometheus-operator文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)
- [基础环境与网络](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

