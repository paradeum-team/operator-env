# helm线下部署ECK日志收集es禁用tls+收集k8s-pods日志

## 安装 eck-operator

### 添加repo

```
helm repo add elastic https://helm.elastic.co
helm repo update
```

### 下载 crds chart

```
helm pull  elastic/eck-operator-crds
```

### 安装 crds (由于crd是全局资源，不希望 helm 卸载 es eck 时同时卸载 crds ,所以独立安装)

```
helm install elastic-operator-crds  eck-operator-crds-1.3.1.tgz -n elastic-system --create-namespace
```

### 下载eck-operator chart

```
helm pull elastic/eck-operator
```

### 查看helm values

- 命令查看

```
helm show values elastic/eck-operator
```

- 访问 github 中 values.yaml 查看

```
https://github.com/elastic/cloud-on-k8s/blob/1.3/deploy/eck-operator/values.yaml
```

### 本地安装eck-operator

```
helm install elastic-operator eck-operator-1.3.1.tgz -n elastic-system --create-namespace \
--set=installCRDs=false \
--set=webhook.enabled=true \
--set=image.repository=registry.hisun.netwarps.com/eck/eck-operator \
--set=config.containerRegistry=registry.hisun.netwarps.com
```

## 安装 elasticsearch

```
cat>kont-elasticsearch.yaml<<EOF
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: kont
  namespace: elastic-system
spec:
  version: 7.10.2
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  nodeSets:
  - name: default
    count: 1
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
EOF
```

## 安装 kibana

创建 kibana yaml

```
cat>kont-kibana.yaml<<EOF
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kont
spec:
  version: 7.10.2
  count: 1
  elasticsearchRef:
    name: kont
EOF
```

查看 kibana svc 名称

```
kubectl get svc -n elastic-system
```

创建 kibana ingress yaml

```
cat >kont-kb-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kont-kibana
  namespace: elastic-system
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS" # use backend https
spec:
  rules:
  - host: kont-kibana.apps164103.hisun.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kont-kb-http # kibana svc name
            port:
              number: 5601
EOF
```
发布 kibana ingress

```
kubectl apply -f kont-kb-ingress.yaml -n elastic-system
```

kont-kibana.apps164103.hisun.local 解析到 ingress ip

外部访问 kibana 地址

```
https://kont-kibana.apps164103.hisun.local/
```

kibana 默认登录账号为 elastic, 查看密码

```
kubectl get secret kont-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode; echo -n elastic-system
```

## 安装 k8s 集群使用 filebeat

下载

```
https://raw.githubusercontent.com/elastic/cloud-on-k8s/1.3/config/recipes/beats/filebeat_autodiscover.yaml
```

- 修改 version, 
- 添加挂载 localtime
- 删除 kind: Elasticsearch 相关配置(对接现有 es)
- 删除 kind: Kibana 相关配置（对接现有 kibana）

文件内容如下：

k8s-filebeat.yaml

```
apiVersion: beat.k8s.elastic.co/v1beta1
kind: Beat
metadata:
  name: k8s
  namespace: elastic-system
spec:
  type: filebeat
  version: 7.10.2
  elasticsearchRef:
    name: kont
  kibanaRef:
    name: kont
  config:
    filebeat:
      autodiscover:
        providers:
        - type: kubernetes
          node: ${NODE_NAME}
          hints:
            enabled: true
            default_config:
              type: container
              paths:
              - /var/log/containers/*${data.kubernetes.container.id}.log
    processors:
    - add_cloud_metadata: {}
    - add_host_metadata: {}
  daemonSet:
    podTemplate:
      spec:
        serviceAccountName: filebeat
        automountServiceAccountToken: true
        terminationGracePeriodSeconds: 30
        dnsPolicy: ClusterFirstWithHostNet
        hostNetwork: true # Allows to provide richer host metadata
        containers:
        - name: filebeat
          securityContext:
            runAsUser: 0
            # If using Red Hat OpenShift uncomment this:
            #privileged: true
          volumeMounts:
          - name: varlogcontainers
            mountPath: /var/log/containers
          - name: varlogpods
            mountPath: /var/log/pods
          - name: varlibdockercontainers
            mountPath: /var/lib/docker/containers
          - mountPath: /etc/localtime
            name: localtime
            readOnly: true
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
        volumes:
        - name: varlogcontainers
          hostPath:
            path: /var/log/containers
        - name: varlogpods
          hostPath:
            path: /var/log/pods
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: localtime
          hostPath:
            path: /etc/localtime
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
rules:
- apiGroups: [""] # "" indicates the core API group
  resources:
  - namespaces
  - pods
  verbs:
  - get
  - watch
  - list
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: elastic-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: elastic-system
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
```

## 参考: 

[helm 线下部署elasticsearch](https://github.com/paradeum-team/operator-env/blob/main/elasticsearch/helm%20%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85elasticsearch.md)

[Install ECK using the Helm chart](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-install-helm.html)

[cloud-on-k8s-beat-configuration](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-beat-configuration.html)
