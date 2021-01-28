# skywalking 部署

- 1、依赖存储：这里就用部署好的 elasticSearch 7
- 2、helm 使用 `SkyWalking` 部署，能部署后台和ui，也仅仅是 server和ui的deployment部署，没有operator
- 3、helm使用apm-server部署，没有operator，仅仅只是deployment 部署后台服务

**总结：** skywalking没有合适的operator，建议使用yaml 部署

## 1、基础配置
skywalking 部署依赖 elasticSearch部署。 怎么部署es集群，参考对应文档

现在把 es的相关配置需要重建：

### 1.1 创建 namespace
```
kubectl create namespace apm
```

### 1.2、准备jks格式的https 认证。
- **获取es的 https的证书 :** 从es 的secret 的 `quickstart-es-http-certs-internal` 拷贝出来
- **转换证书(crt —> pem)：**`openssl x509 -in ca.crt -out ca.pem -outform PEM`
- **转换证书(pem —> jks):**例如将一个 密码为changeit的ca.pem 格式的证书转换为jks格式的证书，将其命名为es_keystore.jks:
	
	```
	keytool -import -v -trustcacerts -file ca.pem  -keystore es_keystore.jks -keypass changeit -storepass changeit
	```	
- **创建secret:方便后续挂载**
	
	```
	#jks
	kubectl create secret generic es-jks --from-file=./es_keystore.jks -n apm
	#pem
	kubectl create secret generic elastic-certificate-pem --from-file=./elastic-certificate.pem -n apm
 	```

### 1.3、准备es的用户名密码，可以弄成secret :
- **账号:** elastic	
- **查看kibana登录密码:**
	 
	```
	kubectl get secret quickstart-es-elastic-user -n elastic-system -o=jsonpath='{.data.elastic}' | base64 --decode; echo
	
	#output
	x39P7X4d377KLvL2c3xlaVb9
	```
- **创建密码secret:**	
	
	```
	kubectl create secret generic apm-es-elastic-user  --from-literal=elastic=x39P7X4d377KLvL2c3xlaVb9 -n apm
	```

### 1.4 准备镜像
**镜像列表：**

-  **skywalking-oap-server：** 
	- apache/skywalking-oap-server:8.1.0-es7
	- docker.elastic.co/apm/apm-server:7.10.2
-  **skywalking-ui:**  apache/skywalking-ui:8.1.0
-  **elasticsearch:** docker.elastic.co/elasticsearch/elasticsearch:7.10.2


## 2、部署方式一：使用yaml方式
### 2.1 发布 后端服务: skywalking-oap-server

**发布apm-oap-server.yaml 模板:**

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: skywalking-oap-server
  name: skywalking-oap-server
  namespace: apm
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: skywalking-oap-server
  strategy:
    resources: {}
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: skywalking-oap-server
    spec:
      containers:
        - env:
            - name: SW_STORAGE
              value: elasticsearch7
            - name: SW_ES_USER
              value: elastic
            - name: SW_ES_PASSWORD
              valueFrom:
                secretKeyRef:
                  key: elastic
                  name: kont-es-elastic-user
            - name: SW_STORAGE_ES_CLUSTER_NODES
              value: 'quickstart-es-http.elastic-system.svc:9200'
            - name: SW_STORAGE_ES_HTTP_PROTOCOL
              value: https
            - name: SW_SW_STORAGE_ES_SSL_JKS_PATH
              value: /skywalking/ext-config/es_keystore.jks
            - name: SW_SW_STORAGE_ES_SSL_JKS_PASS
              value: changeit
            - name: SW_STORAGE_ES_BULK_ACTIONS
              value: '4000'
            - name: SW_STORAGE_ES_FLUSH_INTERVAL
              value: '30'
            - name: SW_STORAGE_ES_QUERY_MAX_SIZE
              value: '8000'
            - name: SW_STORAGE_ES_CONCURRENT_REQUESTS
              value: '4'
            - name: SW_STORAGE_ES_BULK_SIZE
              value: '40'
            - name: JAVA_OPTS
              value: '-Duser.timezone=GMT+8 '
          image: 'apache/skywalking-oap-server:8.1.0-es7'
          imagePullPolicy: IfNotPresent
          securityContext:
            privileged: true
          name: skywalking-oap-server
          ports:
            - containerPort: 1234
              protocol: TCP
            - containerPort: 11800
              protocol: TCP
            - containerPort: 12800
              protocol: TCP
          resources: {}
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
            - mountPath: /skywalking/ext-config
              name: cert-ca
              readOnly: true
            - mountPath: /etc/localtime
              name: localtime
              readOnly: true
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
        - name: cert-ca
          secret:
            defaultMode: 420
            secretName: es-jks
        - hostPath:
            path: /etc/localtime
            type: ''
          name: localtime

 ---

apiVersion: v1
kind: Service
metadata:
  name: skywalking-oap-server
  namespace: apm
  labels:
    app: skywalking-oap-server
spec:
  type: ClusterIP
  ports:
    - name: http1
      protocol: TCP
      port: 1234
      targetPort: 1234
    - name: http2
      protocol: TCP
      port: 11800
      targetPort: 11800
    - name: http3
      protocol: TCP
      port: 12800
      targetPort: 12800
  selector:
    app: skywalking-oap-server

```

执行命令：`kubectl apply -f apm-oap-server.yaml -n apm `

### 2.2 使用yaml 部署skywalking-ui
**发布模板：skywalking-ui.yaml**

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: skywalking-ui
  name: skywalking-ui
  namespace: apm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: skywalking-ui
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: skywalking-ui
    spec:
      containers:
        - env:
            - name: SW_OAP_ADDRESS
              value: 'apm-skywalking-apm-server.apm:8200'
          image: 'apache/skywalking-ui:8.1.0'
          imagePullPolicy: IfNotPresent
          name: skywalking-ui
          ports:
            - containerPort: 8080
              name: http
              protocol: TCP
          resources: {}
          terminationMessagePath: /dev/termination-log
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
  name: skywalking-ui
  namespace: apm
  labels:
    app: skywalking-ui
spec:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 8080
      targetPort: http
  selector:
    app: skywalking-ui
---

```

执行命令：`kubectl apply -f skywalking-ui.yaml -n apm `

### 2.3 卸载
```
kubectl delete -f apm-oap-server.yaml -n apm 
kubectl delete -f skywalking-ui.yaml -n apm
```


## 3、部署方式二：使用helm 的skywalking 安装
### 3.1 添加repo，更新repo
```
helm repo add elastic https://helm.elastic.co
helm repo update
```

### 3.2 下载仓库
 `git clone https://github.com/apache/skywalking-kubernetes`

### 3.3 安装repo
```
git clone https://github.com/apache/skywalking-kubernetes
cd skywalking-kubernetes/chart
helm repo add elastic https://helm.elastic.co
helm dep up skywalking
```

### 3.4 修改参数：
`./skywalking/values-my-es.yaml`

这里没有跑通：

```
oap:
  image:
    tag: 8.1.0-es7      # Set the right tag according to the existing Elasticsearch version
  storageType: elasticsearch7
  env:
  - key: SW_STORAGE_ES_HTTP_PROTOCOL
    value: https
  - key: SW_SW_STORAGE_ES_SSL_JKS_PATH
    value: /skywalking/ext-config/es_keystore.jks
  - key: SW_SW_STORAGE_ES_SSL_JKS_PASS
    value: changeit

ui:
  image:
    tag: 8.1.0

elasticsearch:
  enabled: false
  config:               # For users of an existing elasticsearch cluster,takes effect when `elasticsearch.enabled` is false
    host: your.elasticsearch.host.or.ip
    port:
      http: 9200
    user: "elastic"         # [optional]
    password: "x39P7X4d377KLvL2c3xlaVb9"     # [optional]
```

### 3.5 执行安装

```
helm install apm-skywalking skywalking -n apm -f ./skywalking/values-my-es.yaml
```

### 3.6 卸载: 
`helm uninstall apm-skywalking -n apm`

## 4、部署方式三：仅仅apm-server部署后端，yaml部署ui
### 4.1 下载离线的chart
打开 `https://helm.elastic.co/`  有很多list

**下载 chart：**

- apm-server:
	
	```
	helm pull elastic/apm-server
	或者
	https://helm.elastic.co/helm/apm-server/apm-server-7.10.2.tgz
	```
- skywalking-ui: 这里没有需要使用yaml 方式部署

### 4.2 定义values.yaml
由于这里的模板与skywalking不一样，所以只能从 tgz 包解压获得

**apm-server-values..yaml**

```
apmConfig:
  apm-server.yml: |
    apm-server:
      host: "0.0.0.0:8200"
    queue: {}
    output.elasticsearch:
      username: 'elastic'
      password: 'x39P7X4d377KLvL2c3xlaVb9'
      hosts: ["quickstart-es-http.elastic-system:9200"]
      protocol: https
      ssl.certificate_authorities:
        - /usr/share/apm-server/config/certs/elastic-certificate.pem

replicas: 1

secretMounts:
  - name: elastic-certificate-pem
    secretName: elastic-certificate-pem
    path: /usr/share/apm-server/config/certs

```

### 4.3 离线部署 oap-server
```
helm install apm-skywalking apm-server-7.10.2.tgz -n apm -f apm-server-values.yaml
```
### 4.4 使用yaml部署ui 参考 
参考第二节内容

### 4.5 卸载
```
helm uninstall apm-skywalking  -n apm 
kubectl delete -f skywalking-ui.yaml -n apm
```

## 5 验证
###  5.1 查看部署 以及pod 状态
```
kubectl get pods --namespace=apm  -w
```

### 5.2 访问，验证
访问 ui： 8080端口暴露: `http://localhost:8080`

```
Get the UI URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace apm -l "app=apm-skywalking,release=apm-skywalking,component=ui" -o jsonpath="{.items[0].metadata.name}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl port-forward $POD_NAME 8080:8080 --namespace apm
```


## 参考资料
- [elastic-apm](https://github.com/elastic/apm)
- [apm-server](https://github.com/elastic/helm-charts/blob/master/apm-server/examples/security/values.yaml)
- [skywalking-k8s 部署](https://github.com/apache/skywalking-kubernetes/blob/master/README.md)
- [Skywalking 通过 HTTPS SSL 认证连接](https://skywalking-handbook.netlify.app/extensions/es_https/)
- [k8s 中文文档 ](http://docs.kubernetes.org.cn/468.html)