# helm线下部署kafka-opertor

## 部署 cert-manager

参考：[线下安装cert-manager](../cert-manager/%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85cert-manager.md)

## 部署 zookeeper

参考：[helm线下安装zookeeper-operatoor](../zookeeper-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2zookeeper.md)

## 部署kafka

### 部署 kafka-operator

#### chart values

```
https://github.com/banzaicloud/kafka-operator/blob/master/charts/kafka-operator/values.yaml
```

#### 相关镜像推送到私有仓库

```
docker.mirrors.ustc.edu.cn/kubesphere/kube-rbac-proxy:v0.8.0
ghcr.io/banzaicloud/kafka-operator:v0.18.3
ghcr.io/banzaicloud/jmx-javaagent:0.15.0
ghcr.io/banzaicloud/cruise-control:2.5.68
ghcr.io/banzaicloud/kafka:2.13-2.8.1
```

#### 在安装chart之前，必须首先安装kafka-operator CustomResourceDefinition资源。这是一个单独的步骤，允许您轻松卸载和重新安装kafka-operator，而不删除您已安装的自定义资源。

```
wget https://github.com/banzaicloud/kafka-operator/releases/download/v0.18.3/kafka-operator.crds.yaml
kubectl create --validate=false  -f kafka-operator.crds.yaml
```

#### 添加 repo

```
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
helm repo update
```

#### 下载 chart

```
mkdir ~/kafka
cd ~/kafka
helm pull banzaicloud-stable/kafka-operator --version v0.4.13
```

#### 自定义 values

```
# 私有镜像仓库地址
repository="registry.hisun.netwarps.com"

cat <<EOF > kafka-operator-values.yaml 
operator:
  annotations: {}
  image:
    repository: ${repository}/banzaicloud/kafka-operator
    tag: v0.18.3
    pullPolicy: IfNotPresent
certManager:
  namespace: "cert-manager"
  enabled: true
 
prometheusMetrics:
  enabled: true
  authProxy:
    enabled: true
    image:
      repository: ${repository}/kubebuilder/kube-rbac-proxy
      tag: v0.8.0
      pullPolicy: IfNotPresent
    serviceAccount:
      create: true
      name: kafka-operator-authproxy
EOF
```

```
helm upgrade --install kafka-operator --create-namespace --namespace=kafka -f kafka-operator-values.yaml  kafka-operator-0.4.13.tgz
```

查看 pod

```
kubectl get pod -n kafka
```

#### 部署 kakfa(只内部使用)

```
wget https://raw.githubusercontent.com/banzaicloud/koperator/v0.18.3/config/samples/simplekafkacluster.yaml
```

获取 zk svc 名称 

```
kubectl get svc -n zookeeper

NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
kafka-zk-zookeeper-client     ClusterIP   10.110.60.213    <none>        2181/TCP                              11d
```

修改或添加`simplekafkacluster.yaml`文件中 下面内容, brokers 为节点数量，可以填写多个

```
...
spec:
  ...
  zkAddresses:
    - "kafka-zk-zookeeper-client.zookeeper.svc:2181"
  ...
  readOnlyConfig: |
    auto.create.topics.enable=true
    default.replication.factor=2
    num.partitions=16
    cruise.control.metrics.topic.auto.create=true
    cruise.control.metrics.topic.num.partitions=2
    cruise.control.metrics.topic.replication.factor=2
  ...
  clusterImage: "registry.hisun.netwarps.com/banzaicloud/kafka:2.13-2.6.0-bzc.1"
  ...
  brokerConfigGroups:
    default:
      ...
      storageConfigs:
        - mountPath: "/kafka-logs"
          pvcSpec:
            storageClassName: local-volume
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
  ...
  brokers:
  - id: 0
    brokerConfigGroup: "default"
  - id: 1
    brokerConfigGroup: "default"
  - id: 2
    brokerConfigGroup: "default"
  ...  
  monitoringConfig:
    jmxImage: "registry.hisun.netwarps.com/banzaicloud/jmx-javaagent:0.14.0"
    pathToJar: "/opt/jmx_exporter/jmx_prometheus_javaagent-0.14.0.jar"
  ...
  cruiseControlConfig:
    image: registry.hisun.netwarps.com/banzaicloud/cruise-control:2.5.23
    ...
```

部署

```
kubectl apply -n kafka -f simplekafkacluster.yaml
```
查看 pod 状态

```
kubectl get pod -n kafka

NAME                                      READY   STATUS    RESTARTS   AGE
kafka-0-fmsmp                             1/1     Running   0          22h
kafka-1-t66jg                             1/1     Running   0          22h
kafka-2-vgknq                             1/1     Running   0          22h
kafka-cruisecontrol-7c87c6d9b7-qtzwx      1/1     Running   0          22h
kafka-operator-operator-c456b7d87-b8mrd   2/2     Running   0          23h
prometheus-kafka-prometheus-0             2/2     Running   1          7m29s
```

#### 部署外部使用 kafka 

下载 kafka 部署 文件

```
wget https://github.com/banzaicloud/koperator/raw/chart/kafka-operator/0.4.13/config/samples/simplekafkacluster-with-nodeport-external.yaml
```

分配内网独立使用ip, 公有主机需要申请内网 VIP

```
172.16.152.20
172.16.142.252
172.16.233.132
```

修改 simplekafkacluster-with-nodeport-external.yaml 中下面相关内容

```
spec:
  ...
  zkAddresses:
    - "kafka-zk-zookeeper-client.zookeeper.svc:2181" # zk 内部地址
  ...
  clusterImage: "registry.hisun.netwarps.com/banzaicloud/kafka:2.13-2.8.1"
  readOnlyConfig: |
    auto.create.topics.enable=true
    default.replication.factor=2
    num.partitions=16
    cruise.control.metrics.topic.auto.create=true
    cruise.control.metrics.topic.num.partitions=2
    cruise.control.metrics.topic.replication.factor=2
   ...
     brokerConfigGroups:
    default:
      storageConfigs:
        - mountPath: "/kafka-logs"
          pvcSpec:
            storageClassName: local-path # 当前 k8s 集群选择使用的 storageclass
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
   ...
     brokers:
    - id: 0
      brokerConfigGroup: "default"
      brokerConfig:
        nodePortExternalIP:
          external: "172.16.152.20" # if "hostnameOverride" is not set for "external" external listener than broker is advertised on this IP
    - id: 1
      brokerConfigGroup: "default"
      brokerConfig:
        nodePortExternalIP:
          external: "172.16.142.252" # if "hostnameOverride" is not set for "external" external listener than broker is advertised on this IP
    - id: 2
      brokerConfigGroup: "default"
      brokerConfig:
        nodePortExternalIP:
          external: "172.16.233.132" # if "hostnameOverride" is not set for "external" external listener than broker is advertised on this IP
   
```

查看 kafka pod 

```
kubectl get pod -n kafka
```

```
NAME                                       READY   STATUS    RESTARTS   AGE
kafka-0-9wgvh                              1/1     Running   0          91m
kafka-1-b79qg                              1/1     Running   0          92m
kafka-2-7zcbw                              1/1     Running   0          91m
kafka-cruisecontrol-7986b955cc-tjdsd       1/1     Running   0          4h14m
kafka-operator-operator-56d57954b8-txnqx   2/2     Running   0          4h41m
```

查看 kafka 相关 svc

```
kubectl get svc -n kafka
```
显示如下

```
NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP      PORT(S)                                 AGE
kafka-0                       ClusterIP   10.109.176.191   <none>           29092/TCP,29093/TCP,9094/TCP,9020/TCP   4h16m
kafka-0-external              NodePort    10.98.218.228    172.16.152.20    9094:32000/TCP                          4h16m
kafka-1                       ClusterIP   10.101.6.215     <none>           29092/TCP,29093/TCP,9094/TCP,9020/TCP   4h15m
kafka-1-external              NodePort    10.98.255.216    172.16.142.252   9094:32001/TCP                          4h16m
kafka-2                       ClusterIP   10.97.133.183    <none>           29092/TCP,29093/TCP,9094/TCP,9020/TCP   4h14m
kafka-2-external              NodePort    10.109.106.200   172.16.233.132   9094:32002/TCP                          4h16m
kafka-all-broker              ClusterIP   10.102.236.252   <none>           29092/TCP,29093/TCP,9094/TCP            4h16m
kafka-cruisecontrol-svc       ClusterIP   10.103.205.205   <none>           8090/TCP,9020/TCP                       4h13m
kafka-operator-alertmanager   ClusterIP   10.97.164.125    <none>           9001/TCP                                7h49m
kafka-operator-authproxy      ClusterIP   10.102.177.213   <none>           8443/TCP                                7h49m
kafka-operator-operator       ClusterIP   10.105.112.44    <none>           443/TCP                                 7h49m
```

#### 对接 prometheus 监控

下载 kafkacluster prometheus 部署示例 yaml

```
wget https://raw.githubusercontent.com/banzaicloud/kafka-operator/v0.18.3/config/samples/kafkacluster-prometheus.yaml
```

修改镜像源为私有源

```
sed -i 's/ghcr.io/registry.hisun.netwarps.com/g' kafkacluster-prometheus.yaml
```

然后按下面方法其中一项对接监控

##### 方法一： 使用kafka独立prmetheus  收集监控数据

修改默认使用的 storageClass

```
sed  -i "s/storageClass: 'gp2'/storageClass: 'local-path'/g" kafkacluster-prometheus.yaml
```

修改默认 namespace 为 kafka

```
sed -i 's/namespace: default/namespace: kafka/g' kafkacluster-prometheus.yaml
```

执行部署 kafka 自带监控

```
kubectl apply -f kafkacluster-prometheus.yaml -n kafka
```

grafana 创建Data Source

grafana 首页左边菜单 Configuration-->Data sources

点击`Add data source`

`Name` 输入 `Prometheus-kafka`

`URL` 输入 `http://prometheus-operated.kafka.svc:9090`

点击 `Save & Test`

##### 方法二： 收集 已经存在 prometheus 收集 kafka 监控数据
查看已经部署的 prometheus 相关配置

```
kubectl get prometheus prometheus-community-kube-prometheus -o yaml -n monitoring
```

看到下面相关 Selector 内容

```
  ...
  podMonitorSelector:
    matchLabels:
      release: prometheus-community
  ...
  ruleSelector:
    matchLabels:
      app: kube-prometheus-stack
      release: prometheus-community    
  ...
  serviceMonitorSelector:
    matchLabels:
      release: prometheus-community
```

按已有 `prometheus`中 `Selector` 配置 修改 `kafkacluster-prometheus.yaml` 

```
...
kind: ServiceMonitor
metadata:
  name: kafka-servicemonitor
  labels:
    ...
    release: prometheus-community # 改为 prometheus Selector 中内容
    ...
kind: ServiceMonitor
metadata:
  name: cruisecontrol-servicemonitor
  labels:
    release: prometheus-community # 改为 prometheus Selector 中内容...
kind: PrometheusRule
metadata:
  ...
  labels:
    prometheus: kafka-rules # 不变
    app: kube-prometheus-stack # 改为 prometheus Selector 中内容
    release: prometheus-community # 改为 prometheus Selector 中内容
...
# 删除下面相关内容
kind: ServiceAccount 相关内容
kind: ClusterRole
kind: ClusterRoleBinding
kind: Prometheus
```

执行部署

```
kubectl apply -f kafkacluster-prometheus.yaml -n kafka
```


##### 导入 grafana dashboard

[kafka-looking-glass.json](./grafana-dashboard/kafka-looking-glass.json)


注意：使用独立 prometheus 数据源查看图表时需要选择 data_source 为 Prometheus-kafka 再点击保存

#### 创建 kafka-cruisecontrol ingress（operator 自带管理页面）

创建 kafka-cruisecontrol-ingress.yaml（根据环境修改 host）

```
cat <<EOF > kafka-cruisecontrol-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kafka-cruisecontrol
  namespace: kafka
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: kafka-cruisecontrol.apps164103.hisun.k8s
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kafka-cruisecontrol-svc
            port:
              number: 8090
EOF
```

```
kubectl apply -f kafka-cruisecontrol-ingress.yaml -n kafka
```

域名解析后访问ui： `http://kafka-cruisecontrol.apps164103.hisun.k8s/`

#### 部署 cmka (原 kafna-manager)

参考：[helm安装cmak-operator(cmak以前叫kafka manager).md](./helm安装cmak-operator(cmak以前叫kafka manager).md)

## 故障处理

### kafka 启动报错

```
Fatal error during KafkaServer startup. Prepare to shutdown (kafka.server.KafkaServer) kafka.common.InconsistentClusterIdException: The Cluster ID kGhqSXdzRCer6Jg5v1ow8g doesn't match stored clusterId Some(l31jTSA8R8aW-lwybxckYg) in meta.properties. The broker is trying to join the wrong cluster. Configured zookeeper.connect may be wrong.
```

解决方法：

清理 zk 数据重启(因为 zk 是 helm 安装的，删除 sts 会自动重建)

```
kubectl delete sts kafka-zk-zookeeper -n zookeeper && kubectl delete pvc data-kafka-zk-zookeeper-0 data-kafka-zk-zookeeper-1 data-kafka-zk-zookeeper-2 -n zookeeper
```

清理 kafka 数据重启(kafka 是 operator 管理，删除 pod 和 svc即可)

```
kubectl delete pod -l app=kafka -n kafka && kubectl delete pvc -l app=kafka -n kafka
```

参考：

[https://github.com/paradeum-team/operator-env/blob/main/kafka-operator/kafka-operator.md](https://github.com/paradeum-team/operator-env/blob/main/kafka-operator/kafka-operator.md)

[https://github.com/banzaicloud/kafka-operator/tree/master/charts/kafka-operator](https://github.com/banzaicloud/kafka-operator/tree/master/charts/kafka-operator)

[https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)

[https://github.com/amuraru/k8s-kafka-the-hard-way/blob/master/grafana-dashboard.yaml](https://github.com/amuraru/k8s-kafka-the-hard-way/blob/master/grafana-dashboard.yaml)

https://github.com/banzaicloud/koperator/tree/master/charts/kafka-operator

https://github.com/banzaicloud/koperator/blob/chart/kafka-operator/0.4.13/config/samples/simplekafkacluster-with-nodeport-external.yaml