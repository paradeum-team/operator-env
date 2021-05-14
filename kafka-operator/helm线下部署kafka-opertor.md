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
docker.mirrors.ustc.edu.cn/kubesphere/kube-rbac-proxy:v0.5.0
ghcr.io/banzaicloud/kafka-operator:v0.14.0
ghcr.io/banzaicloud/jmx-javaagent:0.14.0
ghcr.io/banzaicloud/cruise-control:2.5.23
ghcr.io/banzaicloud/kafka:2.13-2.6.0-bzc.1
```

#### 在安装chart之前，必须首先安装kafka-operator CustomResourceDefinition资源。这是一个单独的步骤，允许您轻松卸载和重新安装kafka-operator，而不删除您已安装的自定义资源。

```
wget https://github.com/banzaicloud/kafka-operator/releases/download/v0.14.0/kafka-operator.crds.yaml
kubectl apply -f kafka-operator.crds.yaml
```

#### 添加 repo

```
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
helm repo update
```

#### 下载 chart

```
helm pull banzaicloud-stable/kafka-operator --version v0.4.6
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
    tag: v0.15.1
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
helm install kafka-operator --create-namespace --namespace=kafka -f kafka-operator-values.yaml  kafka-operator-0.4.6.tgz
```

查看 pod

```
kubectl get pod -n kafka
```

#### 部署 kakfa

```
wget https://raw.githubusercontent.com/banzaicloud/kafka-operator/v0.15.1/config/samples/simplekafkacluster.yaml
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

#### 收集 kafka 监控数据到已安装 prometheus

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

下载 kafkacluster prometheus 部署示例 yaml

```
wget https://raw.githubusercontent.com/banzaicloud/kafka-operator/v0.15.1/config/samples/kafkacluster-prometheus.yaml
```

修改镜像源为私有源

```
sed -i 's/ghcr.io/registry.hisun.netwarps.com/g' kafkacluster-prometheus.yaml
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

```
kubectl apply -f kafkacluster-prometheus.yaml -n kafka
```

导入 grafana dashboard

[kafka-looking-glass.json](./grafana_dashboard/kafka-looking-glass.json)


#### 创建 ingress

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