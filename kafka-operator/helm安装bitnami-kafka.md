# helm安装bitnami/kafka

## 安装 zookeeper

参考：[./zk-operator.md](./zk-operator.md)

## 添加bitnami charts repo

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## 下载 kafka chart

```
mkdir -p ~/bitnami-kafka
cd ~/bitnami-kafka
helm pull bitnami/kafka
```

## 创建 values.yaml

```
replicaCount: 3
persistence:
  storageClass: "local-volume"
  size: 50Gi
metrics:
  kafka:
    enabled: true
externalAccess:
  enabled: true
zookeeper:
  enabled: false
externalZookeeper:
  servers:
  - bfs-kafka-zk-zookeeper-0.zookeeper.svc:2181
  - bfs-kafka-zk-zookeeper-1.zookeeper.svc:2181
  - bfs-kafka-zk-zookeeper-2.zookeeper.svc:2181
```

## 部署

```
helm upgrade --install bfs-kafka kafka-14.2.0.tgz -n bitnami-kafka --create-namespace -f values.yaml 
```

## 安装  cmak (kafka-manager)

参考: [helm安装cmak-operator.md](helm安装cmak-operator(cmak以前叫kafka manager).md)

## 参考

https://artifacthub.io/packages/helm/bitnami/kafka

https://github.com/bitnami/charts/blob/master/bitnami/kafka/values.yaml
