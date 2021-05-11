# 应用日志对接kafka+es

## 部署filebeat

创建`kont-filebeat.yaml`

```
apiVersion: beat.k8s.elastic.co/v1beta1
kind: Beat
metadata:
  name: kont
spec:
  type: filebeat
  version: 7.12.0
  config:
    logging.level: info
    filebeat.inputs:
    - type: log
      paths:
      - /data/kont/kont-workflow/log/app/*.log
      fields:
        log_topic: "kont-workflow"
      tags: ["kont-workflow"]
    - type: log
      paths:
      - /data/kont/kont-base/log/app/*.log
      fields:
        log_topic: "kont-base"
      tags: ["kont-base"]
    - type: log
      paths:
      - /data/kont/kont-gateway/log/app/*.log
      fields:
        log_topic: "kont-gateway"
      tags: ["kont-gateway"]
    - type: log
      paths:
      - /data/kont/kont-ddep/log/app/*.log
      fields:
        log_topic: "kont-ddep"
      tags: ["kont-ddep"]
    - type: log
      paths:
      - /data/kont/kont-tdmo/log/app/*.log
      fields:
        log_topic: "kont-tdmo"
      tags: ["kont-tdmo"]
    - type: log
      paths:
      - /data/kont/kont-meta/log/app/*.log
      fields:
        log_topic: "kont-meta"
      tags: ["kont-meta"]
    - type: log
      paths:
      - /data/kont/kont-xxljob/log/app/*.log
      fields:
        log_topic: "kont-xxljob"
      tags: ["kont-xxljob"]
    output.kafka:
      hosts: ["kafka-headless.kafka.svc:29092"]
      topic: '%{[fields.log_topic]}'
      partition.round_robin:
        reachable_only: false
      required_acks: 1
      compression: gzip
      max_message_bytes: 1000000
  daemonSet:
    podTemplate:
      spec:
        dnsPolicy: ClusterFirstWithHostNet
        nodeSelector:
          node-role.kubernetes.io/compute: 'true'
        hostNetwork: true
        securityContext:
          runAsUser: 0
        containers:
        - name: filebeat
          securityContext:
            runAsUser: 0
            # If using Red Hat OpenShift uncomment this:
            privileged: true
          volumeMounts:
          - name: applog
            mountPath: /data/kont
            readOnly: true
          - mountPath: /etc/localtime
            name: localtime
            readOnly: true
        volumes:
        - name: applog
          hostPath:
            path: /data/kont/
            type: DirectoryOrCreate
        - name: localtime
          hostPath:
            path: /etc/localtime
```

安装 kont-filebeat

```
kubectl apply -f kont-filebeat.yaml
```

查看 pods

```
kubectl get pod -n elastic-system
```

## 部署 logstash

创建 `kont-logstash.yaml`

```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kont-logstash-configmap
data:
  logstash.yml: |
    http.host: "0.0.0.0"
    path.config: /usr/share/logstash/pipeline
  logstash.conf: |
    # all input will come from filebeat, no local logs
    input {
      kafka {
        bootstrap_servers => "kafka-headless.kafka.svc:29092"
        group_id => "kont"
        client_id => "ls-kont"
        consumer_threads => 4
        topics => ["kont-workflow", "kont-base", "kont-gateway", "kont-ddep", "kont-tdmo", "kont-meta", "kont-xxljob"]
        codec => json { charset => "UTF-8" }
      }
    }
    filter {
      json{
        source => "message"
      }
      mutate{
        rename => ["msg","message"]
      }
      date{
        match => ["T", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"]
        target => "T"
        timezone => "+08:00"
        locale => "cn"
      }
    }
    output {
      elasticsearch {
        index => "kont-apps"
        action => "create"
        hosts => [ "http://kont-es-http.elastic-system.svc:9200" ]
        user => "${ELASTICSEARCH_USER}"
        password => "${ELASTICSEARCH_PASSWORD}"
        #cacert => '/etc/logstash/certificates/ca.crt'
      }
    }
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: kont-logstash-data
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
  name: kont-logstash
  namespace: elastic-system
  labels:
    app: kont-logstash
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kont-logstash
  template:
    metadata:
      labels:
        app: kont-logstash
    spec:
      containers:
      - image: registry.hisun.netwarps.com/logstash/logstash:7.12.0
        name: kont-logstash
        ports:
        - containerPort: 25826
        - containerPort: 5044
        env:
        - name: ES_HOSTS
          value: "http://kont-es-http.elastic-system.svc:9200"
        - name: ELASTICSEARCH_USER
          value: "elastic"
        - name: ELASTICSEARCH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: kont-es-elastic-user
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
          name: kont-logstash-configmap
          items:
            - key: logstash.yml
              path: logstash.yml
      - name: logstash-pipeline-volume
        configMap:
          name: kont-logstash-configmap
          items:
            - key: logstash.conf
              path: logstash.conf
      - name: data
        persistentVolumeClaim:
          claimName: kont-logstash-data
      - name: localtime
        hostPath:
          path: /etc/localtime
```

安装 kont-logstash

```
kubectl apply -f kont-logstash.yaml
```

查看 pods

```
kubectl get pod -n elastic-system
```
## kibana 创建索引

### 登录 kibana
kibana 默认登录账号为 elastic, 查看密码

```
kubectl get secret kont-es-elastic-user -o=jsonpath='{.data.elastic}' -n elastic-system| base64 --decode; echo
```

访问 kibana 管理页面

```
https://kont-kibana.apps181227.hisun.k8s/
```

### 创建索引

左边总菜单-->  最下方 Stack Management --> Index Patterns --> Create index pattern

`Index pattern name` 输入 kont-apps

`Time field` 选择 T

点击 Create index pattern

### 创建索引模板

左边总菜单--> `Index Management` --> Index Templates --> Create Template 


`Name` 输入 `kont-apps`

`Index patterns` 输入 `ont-apps`

`Data stream` 开启 `Create data stream`

点击 `Next`


选择 logs-mappings、logs-settings

点击 `Next`

其它都是直接点 `Next`

直到最后 Review details for 'kont-apps'

点击 `Create Template`

### 绑定索引生命周期策略

左边总菜单--> Stack Management --> Index Lifecycle Policies

选中 `logs` 对应的 `Actions` --> Add policy to index template --> Add policy "logs" to index template

Index template 选择 `kont-apps`

点击 `Add Policy`


### 查询应用日志

左上角总菜单 --> Analyties --> Discover

选择 kont-apps 索引 查询