# helm升级ECK

## 下载镜像列表到私有仓库

```
docker.elastic.co/eck/eck-operator:1.5.0
docker.elastic.co/elasticsearch/elasticsearch:7.12.0
docker.elastic.co/kibana/kibana:7.12.0
docker.elastic.co/beats/filebeat:7.12.0
docker.elastic.co/logstash/logstash:7.12.0
```

## 下载最新 eck-operator-crds chart

```
helm repo update
helm pull  elastic/eck-operator-crds
```

## 升级 eck-operator-crds 

```
helm upgrade elastic-operator-crds  eck-operator-crds-1.5.0.tgz -n elastic-system --create-namespace
```

## 下载最新 eck-operator chart

```
helm pull elastic/eck-operator
```

## 升级 eck-operator（一般情况，更新设置的参数 同安装时参数 ）

```
helm upgrade elastic-operator eck-operator-1.5.0.tgz -n elastic-system \
--set=installCRDs=false \
--set=webhook.enabled=true \
--set=image.repository=registry.hisun.netwarps.com/eck/eck-operator \
--set=config.containerRegistry=registry.hisun.netwarps.com
```

## 升级 elasticsearch

修改 发布 yaml 中 version 字段值为 `7.12.0`

```
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: kont
  namespace: elastic-system
spec:
  version: 7.12.0
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  nodeSets:
  - name: default
    count: 3
    config:
      node.roles: ["master", "data", "ingest", "ml", "transform"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data # pvc 名称不支持修改
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
        storageClassName: local-path
    podTemplate:
      spec:
        #nodeSelector:
        #  node-role.kubernetes.io/logging: 'true'
        initContainers:
        - name: sysctl
          securityContext:
            privileged: true
          command: ['sh', '-c', 'sysctl -w vm.max_map_count=262144']
        containers:
        - name: elasticsearch
          securityContext:
            privileged: true
```

执行升级

```
kubectl apply -f kont-elasticsearch.yaml
```

## 升级 kibana

类似 es 修改 version 为 7.12.0，执行升级

## 升级 filebeat 

类似 es 修改 version 为 7.12.0，执行升级

## 升级 logstash

类似 es 修改 version 为 7.12.0，执行升级
