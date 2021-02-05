# helm离线部署kafka说明 
在k8s集群上使用kafka的operator 来安装kafka集群。

欲搭建kafka 环境，需要先搭建kafka的依赖的环境。

依赖如下：

- cert-manager
	- **0.15.x:** Kafka operator 0.8.x and newer supports cert-manager 0.15.x
	- **0.10.x:** Kafka operator 0.7.x supports cert-manager 0.10.x
- zookeeper
- Prometheus

## 1、环境准备
- 准备cert-manager环境
- 搭建好zk环境

## 2、下载离线的chart

```
# 添加repo
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
helm repo update

# 下载chart到本地
helm pull banzaicloud-stable/kafka-operator --version v0.14.0

```


## 3、下载相关镜像并推送到私有仓库
**私有仓库地址：**`registry.hisun.netwarps.com`

**镜像 List:**

```
ghcr.io/banzaicloud/kafka-operator:v0.14.0
gcr.io/kubebuilder/kube-rbac-proxy:v0.5.0
ghcr.io/banzaicloud/jmx-javaagent:0.14.0
ghcr.io/banzaicloud/cruise-control:2.5.23
ghcr.io/banzaicloud/kafka:2.13-2.6.0-bzc.1
```

## 4、创建namespace

```
kubectl create namespace kafka
```

## 5、部署kafka-operator
### 5.0 安装kafka-operator对应的crd资源
```
kubectl apply --validate=false -f https://github.com/banzaicloud/kafka-operator/releases/download/v0.12.3/kafka-operator.crds.yaml

```

### 5.1、自定义values.yaml


```
# 域名后缀
domain="apps164103.hisun.local"
# 私有镜像仓库地址
repository="registry.hisun.netwarps.com"

cat <<EOF > kafka-operator-stack-values.yaml 
operator:
  annotations: {}
  image:
    repository: registry.hisun.netwarps.com/banzaicloud/kafka-operator
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
      repository: registry.hisun.netwarps.com/kubebuilder/kube-rbac-proxy
      tag: v0.5.0
      pullPolicy: IfNotPresent
    serviceAccount:
      create: true
      name: kafka-operator-authproxy
EOF

```

### 5.2 、exec install operator


```
# 需要继续替换镜像

helm install kafka-operator kafka-operator-0.4.4.tgz \
--set certManager.namespace=cert-manager \
--set operator.image.repository=registry.hisun.netwarps.com/banzaicloud/kafka-operator  \
--set prometheusMetrics.authProxy.image.repository=registry.hisun.netwarps.com/kubebuilder/kube-rbac-proxy    \
-n kafka  

```



### 5.3、 卸载operator
```
 helm delete  kafka-operator -n kafka
```



## 6、 部署kafka应用
### 3.1 安装部署 kafka集群

核对 `config/samples/simplekafkacluster.yaml` 文件，如果zk 安装在 命名空间`zookeeper`下，可以忽略核对

- 指定namespace 为kafka 如：`namespace: kafka`
- 核对zk的连接地址endpoint。 


### 3.2 修改 发布模板
**模板：**`simplekafkacluster.yaml`修改zk 配置



```
apiVersion: kafka.banzaicloud.io/v1beta1
kind: KafkaCluster
metadata:
  labels:
    controller-tools.k8s.io: "1.0"
  name: kafka
  namespace: kafka
spec:
  headlessServiceEnabled: true
  zkAddresses:
    - "kafka-zk-zookeeper-client.zookeeper:2181"
  propagateLabels: false
  oneBrokerPerNode: false
  clusterImage: "registry.hisun.netwarps.com/banzaicloud/kafka:2.13-2.6.0-bzc.1"
  readOnlyConfig: |
    auto.create.topics.enable=false
    cruise.control.metrics.topic.auto.create=true
    cruise.control.metrics.topic.num.partitions=1
    cruise.control.metrics.topic.replication.factor=2
  brokerConfigGroups:
    default:
      storageConfigs:
        - mountPath: "/kafka-logs"
          pvcSpec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 5Gi
      brokerAnnotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9020"
  brokers:
    - id: 0
      brokerConfigGroup: "default"
    - id: 1
      brokerConfigGroup: "default"
    - id: 2
      brokerConfigGroup: "default"
  rollingUpgradeConfig:
    failureThreshold: 1
  listenersConfig:
    internalListeners:
      - type: "plaintext"
        name: "internal"
        containerPort: 29092
        usedForInnerBrokerCommunication: true
      - type: "plaintext"
        name: "controller"
        containerPort: 29093
        usedForInnerBrokerCommunication: false
        usedForControllerCommunication: true
  cruiseControlConfig:
    cruiseControlTaskSpec:
      RetryDurationMinutes: 5
    topicConfig:
      partitions: 12
      replicationFactor: 3
    config: |
      num.metric.fetchers=1
      metric.sampler.class=com.linkedin.kafka.cruisecontrol.monitor.sampling.CruiseControlMetricsReporterSampler
      metric.reporter.topic.pattern=__CruiseControlMetrics
      sample.store.class=com.linkedin.kafka.cruisecontrol.monitor.sampling.KafkaSampleStore
      partition.metric.sample.store.topic=__KafkaCruiseControlPartitionMetricSamples
      broker.metric.sample.store.topic=__KafkaCruiseControlModelTrainingSamples
      sample.store.topic.replication.factor=2
      num.sample.loading.threads=8
      metric.sampler.partition.assignor.class=com.linkedin.kafka.cruisecontrol.monitor.sampling.DefaultMetricSamplerPartitionAssignor
      metric.sampling.interval.ms=120000
      metric.anomaly.detection.interval.ms=180000
      partition.metrics.window.ms=300000
      num.partition.metrics.windows=1
      min.samples.per.partition.metrics.window=1
      broker.metrics.window.ms=300000
      num.broker.metrics.windows=20
      min.samples.per.broker.metrics.window=1
      capacity.config.file=config/capacity.json
      default.goals=com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.PotentialNwOutGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.TopicReplicaDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.LeaderBytesInDistributionGoal
      goals=com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.PotentialNwOutGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.TopicReplicaDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.LeaderBytesInDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.kafkaassigner.KafkaAssignerDiskUsageDistributionGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.PreferredLeaderElectionGoal
      hard.goals=com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuCapacityGoal
      min.monitored.partition.percentage=0.95
      cpu.balance.threshold=1.1
      disk.balance.threshold=1.1
      network.inbound.balance.threshold=1.1
      network.outbound.balance.threshold=1.1
      replica.count.balance.threshold=1.1
      cpu.capacity.threshold=0.8
      disk.capacity.threshold=0.8
      network.inbound.capacity.threshold=0.8
      network.outbound.capacity.threshold=0.8
      cpu.low.utilization.threshold=0.0
      disk.low.utilization.threshold=0.0
      network.inbound.low.utilization.threshold=0.0
      network.outbound.low.utilization.threshold=0.0
      metric.anomaly.percentile.upper.threshold=90.0
      metric.anomaly.percentile.lower.threshold=10.0
      proposal.expiration.ms=60000
      max.replicas.per.broker=10000
      num.proposal.precompute.threads=1
      num.concurrent.partition.movements.per.broker=10
      execution.progress.check.interval.ms=10000
      anomaly.notifier.class=com.linkedin.kafka.cruisecontrol.detector.notifier.SelfHealingNotifier
      metric.anomaly.finder.class=com.linkedin.kafka.cruisecontrol.detector.KafkaMetricAnomalyFinder
      anomaly.detection.interval.ms=10000
      anomaly.detection.goals=com.linkedin.kafka.cruisecontrol.analyzer.goals.ReplicaCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.DiskCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkInboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.NetworkOutboundCapacityGoal,com.linkedin.kafka.cruisecontrol.analyzer.goals.CpuCapacityGoal
      metric.anomaly.analyzer.metrics=BROKER_PRODUCE_LOCAL_TIME_MS_MAX,BROKER_PRODUCE_LOCAL_TIME_MS_MEAN,BROKER_CONSUMER_FETCH_LOCAL_TIME_MS_MAX,BROKER_CONSUMER_FETCH_LOCAL_TIME_MS_MEAN,BROKER_FOLLOWER_FETCH_LOCAL_TIME_MS_MAX,BROKER_FOLLOWER_FETCH_LOCAL_TIME_MS_MEAN,BROKER_LOG_FLUSH_TIME_MS_MAX,BROKER_LOG_FLUSH_TIME_MS_MEAN
      failed.brokers.zk.path=/CruiseControlBrokerList
      topic.config.provider.class=com.linkedin.kafka.cruisecontrol.config.KafkaTopicConfigProvider
      cluster.configs.file=config/clusterConfigs.json
      completed.user.task.retention.time.ms=21600000
      demotion.history.retention.time.ms=86400000
      max.cached.completed.user.tasks=100
      max.active.user.tasks=5
      self.healing.enabled=true
      webserver.http.port=9090
      webserver.http.address=0.0.0.0
      webserver.http.cors.enabled=false
      webserver.http.cors.origin=http://localhost:8080/
      webserver.http.cors.allowmethods=OPTIONS,GET,POST
      webserver.http.cors.exposeheaders=User-Task-ID
      webserver.api.urlprefix=/kafkacruisecontrol/*
      webserver.ui.diskpath=./cruise-control-ui/dist/
      webserver.ui.urlprefix=/*
      webserver.request.maxBlockTimeMs=10000
      webserver.session.maxExpiryTimeMs=60000
      webserver.session.path=/
      webserver.accesslog.enabled=true
      webserver.accesslog.path=access.log
      webserver.accesslog.retention.days=14
    clusterConfig: |
      {
        "min.insync.replicas": 4
      }

```

### 3.3 执行安装

```
kubectl apply -f ./simplekafkacluster.yaml -n kafka
```

若是对接prometheus 执行

```
kubectl create -n default -f config/samples/kafkacluster-prometheus.yaml
```

### 3.4 kafka集群扩缩

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
kubectl apply -n kafka -f config/samples/simplekafkacluster.yaml
```



## 4 验证kafka

配置 `kafka-cruisecontrol-svc:8090` 或者打通容器和本地的网络[详情](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

然后访问：`http://10.102.231.117:8090/#/` 可以查看kafka的监控状态

或者

```
kubectl port-forward svc/kafka-cruisecontrol-svc 8090:8090 -n kafka
```

然后访问：`http://localhost:8090/#/` 可以查看kafka的监控状态


## 5.卸载
### 5.1 kafka 应用卸载
```
kubectl delete -n kafka -f ./simplekafkacluster.yaml
```
### 5.2  operator 卸载
**helm 方式**

```
helm uninstall kafka-operator -n kafka
```



## 参考文档
- [banzaicloud/kafka-operator 源码](https://github.com/banzaicloud/kafka-operator)
- [kafka-operator 安装文档](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)
- [pravega/zookeeper-operator 源码及docs](https://github.com/pravega/zookeeper-operator)
- [prometheus-operator文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)
- [基础环境与网络](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

