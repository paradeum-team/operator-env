# 使用 journalbeat 收集jounald日志

## 部署 eck

参考：[k8s1.22.2使用helm部署ECK1.8.0+es+kibana+logstash+kafka+filebeat跨k8s集群收集日志.md](./k8s1.22.2使用helm部署ECK1.8.0+es+kibana+logstash+kafka+filebeat跨k8s集群收集日志.md)

## 部署journalbeat输出到 kafka

node-journalbeat.yaml

```
apiVersion: beat.k8s.elastic.co/v1beta1
kind: Beat
metadata:
  name: journald
  namespace: elastic-system
spec:
  type: journalbeat
  version: 7.15.1
  config:
    journalbeat.inputs:
    - paths: []
      seek: cursor
      cursor_seek_fallback: tail
    processors:
    - add_cloud_metadata: {}
    - add_host_metadata: {}
    output.kafka:
      hosts: ["kafka-0.kafka.svc:29092","kafka-1.kafka.svc:29092","kafka-2.kafka.svc:29092"]
      topic: 'node-journalbeat'
      partition.round_robin:
        reachable_only: false
      required_acks: 1
      compression: gzip
      max_message_bytes: 1000000
  daemonSet:
    podTemplate:
      spec:
        automountServiceAccountToken: true # some older Beat versions are depending on this settings presence in k8s context
        dnsPolicy: ClusterFirstWithHostNet
        containers:
        - name: journalbeat
          volumeMounts:
          - mountPath: /var/log/journal
            name: var-journal
          - mountPath: /run/log/journal
            name: run-journal
          - mountPath: /etc/machine-id
            name: machine-id
          securityContext:
            runAsUser: 0
            # If using Red Hat OpenShift uncomment this:
            privileged: true
        hostNetwork: true # Allows to provide richer host metadata
        securityContext:
          runAsUser: 0
        terminationGracePeriodSeconds: 30
        tolerations:
          - effect: NoSchedule
            operator: Exists
        volumes:
        - hostPath:
            path: /var/log/journal
          name: var-journal
        - hostPath:
            path: /run/log/journal
          name: run-journal
        - hostPath:
            path: /etc/machine-id
          name: machine-id
```

部署 node-journalbeat

```
kubectl apply -f node-journalbeat.yaml
```

## 部署kafka

参考：[helm线下部署kafka-opertor.md](../kafka-operator/helm线下部署kafka-opertor.md)

## 部署 journalbeat logstash 读取 kafka 日志，输出到 elasticsearch

node-journalbeat-logstash.yaml

```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: node-journalbeat-logstash-configmap
  namespace: elastic-system
data:
  logstash.yml: |
    http.host: "0.0.0.0"
    path.config: /usr/share/logstash/pipeline
    log.level: info
  logstash.conf: |
    # all input will come from filebeat, no local logs
    input {
      kafka {
        bootstrap_servers => "kafka-0.kafka.svc:29092,kafka-1.kafka.svc:29092,kafka-2.kafka.svc:29092"
        group_id => "journalbeat"
        client_id => "ls-journalbeat"
        consumer_threads => 4
        topics => "node-journalbeat"
        codec => json { charset => "UTF-8" }
      }
    }
    filter {
      json {
        source => "message"
      }
    }
    output {
      elasticsearch {
        index => "node-journalbeat"
        action => "create"
        hosts => [ "http://bfs-es-master.elastic-system.svc:9200" ]
        user => "${ELASTICSEARCH_USER}"
        password => "${ELASTICSEARCH_PASSWORD}"
        #cacert => '/etc/logstash/certificates/ca.crt'
      }
    }
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: node-journalbeat-logstash-data
  namespace: elastic-system
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: node-journalbeat-logstash
  namespace: elastic-system
  labels:
    app: node-journalbeat-logstash
spec:
  replicas: 1
  selector:
    matchLabels:
      app: node-journalbeat-logstash
  template:
    metadata:
      labels:
        app: node-journalbeat-logstash
    spec:
      containers:
      - image: registry.hisun.netwarps.com/logstash/logstash:7.15.1
        name: node-journalbeat-logstash
        ports:
        - containerPort: 25826
        - containerPort: 5044
        env:
        - name: ES_HOSTS
          value: "http://bfs-es-http.elastic-system.svc:9200"
        - name: ELASTICSEARCH_USER
          value: "elastic"
        - name: ELASTICSEARCH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: bfs-es-elastic-user
              key: elastic
        resources: {}
        volumeMounts:
        - name: config-volume
          mountPath: /usr/share/logstash/config
        - name: logstash-pipeline-volume
          mountPath: /usr/share/logstash/pipeline
        - name: data
          mountPath: "/usr/share/logstash/data/"
          subPath: "data"
        - mountPath: /etc/localtime
          name: localtime
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: node-journalbeat-logstash-configmap
          items:
            - key: logstash.yml
              path: logstash.yml
      - name: logstash-pipeline-volume
        configMap:
          name: node-journalbeat-logstash-configmap
          items:
            - key: logstash.conf
              path: logstash.conf
      - name: data
        persistentVolumeClaim:
          claimName: node-journalbeat-logstash-data
      - name: localtime
        hostPath:
          path: /etc/localtime
```

部署 node-journalbeat-logstash

```
kubectl apply -f node-journalbeat-logstash.yaml
```

## kibana 创建索引 

kibana 创建索引  node-journalbeat

## 参考

https://www.elastic.co/guide/en/beats/journalbeat/current/running-on-docker.html

https://www.elastic.co/guide/en/beats/journalbeat/current/kafka-output.html

https://www.elastic.co/guide/en/beats/journalbeat/current/configuring-howto-journalbeat.html
