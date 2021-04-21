# helm 线下部署elasticsearch

----

## 1 下载离线的chart
```
# 添加repo
helm repo add elastic https://helm.elastic.co
helm repo update

# 下载chart到本地
helm pull elastic/eck-operator

# eck-operator-1.3.1.tgz

```

## 2  下载相关镜像并推送到私有仓库
**私有仓库地址：**`registry.hisun.netwarps.com`

**镜像 List:**

- docker.elastic.co/eck/eck-operator:1.3.1
- docker.elastic.co/elasticsearch/elasticsearch:7.10.2
- docker.elastic.co/kibana/kibana:7.10.2

## 3 创建 namespace
```
kubectl create namespace elastic-system
```

## 4 部署 operator

```
helm install elastic-operator eck-operator-1.3.1.tgz -n elastic-system  \
--set webhook.enabled=true \
--set image.repository=registry.hisun.netwarps.com/eck/eck-operator 
```

## 5 更新部署operator

```
helm upgrade elastic-operator eck-operator-1.3.1.tgz -n elastic-system  \
--set webhook.enabled=true \
--set image.repository=registry.hisun.netwarps.com/eck/eck-operator 
```

## 6 部署elasticSearch应用
- 1、**模板文件--1 (master-slave分开)：** elasticsearch.yaml

```
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: es-base
  namespace: elastic-system
spec:
  version: 7.10.2
  image: registry.hisun.netwarps.com/elasticsearch/elasticsearch:7.10.2
  http:
    service:
      spec:
        selector:
          elasticsearch.k8s.elastic.co/cluster-name: "es-base"
          elasticsearch.k8s.elastic.co/node-master: "false"
  nodeSets:
  - name: master
    count: 1
    config:
      node.roles: ["master"]
  - name: data
    count: 5
    config:
      node.roles: ["data"]
```

- 2、**模板文件--2 (master-slave 混合)--默认开启 tls：** elasticsearch.yaml

```
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: es-base
  namespace: elastic-system
spec:
  version: 7.10.2
  image: registry.hisun.netwarps.com/elasticsearch/elasticsearch:7.10.2
  http:
    service:
      spec:
        type: LoadBalancer
  nodeSets:
  - name: default
    count: 3

```

- 3、**模板文件--3(master-slave 混合)--关闭 tls：** elasticsearch.yaml

```
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: es-base
  namespace: elastic-system
spec:
  version: 7.10.2
  image: registry.hisun.netwarps.com/elasticsearch/elasticsearch:7.10.2
  http:
    service:
      spec:
        type: LoadBalancer
    tls:
      selfSignedCertificate:
        disabled: true
  nodeSets:
  - name: default
    count: 3

```


**命令执行:** 这里使用模板3  或者 2 （**建议模板3**）。
区别在于，模板3 关闭了tls，模板2在模板3的基数上，开启tls，应用对接es的时候需要 证书。
部署应用前需要确认master是否可调度，k8s集群安装好后，master默认是不可调度的   
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```
需要执行以上命令，使master可调度


```
kubectl apply -f elasticsearch.yaml -n elastic-system
```



## 7 查看部署 以及pod 状态
```
kubectl --namespace elastic-system get pods

```

## 8 访问，验证
### 8.1 部署kibana
模板文件：kibana_es.yaml

```
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kapp
spec:
  version: 7.10.2
  image: registry.hisun.netwarps.com/kibana/kibana:7.10.2
  count: 1
  elasticsearchRef:
    name: es-base
    namespace: elastic-system
```

The use of `namespace` is optional if the Elasticsearch cluster is running in the same namespace as Kibana.


**执行命令：**

```
kubectl apply -f kibana_es.yaml -n elastic-system
```


### 8.2 访问
#### 8.2.1 本机部署访问   
端口本地暴露：

```
kubectl port-forward svc/kapp-kb-http  -n elastic-system 5601:5601
```

**账号:** elastic

**查看kibana登录密码:**
 
```
kubectl get secret es-base-es-elastic-user -n elastic-system -o=jsonpath='{.data.elastic}' | base64 --decode; echo
```


**访问：** `https://localhost:5601/login`   
#### 8.2.2 非本机部署访问  
编辑kibana-ingress.yaml
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana-ingress
  namespace: elastic-system  #need to check
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: kibana.hisun.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kapp-kb-http #根据实际部署kibana的服务名称修改
            port:
              number: 5601
```
执行kibana ingress部署  
```
kubectl apply -f kibana-ingress.yaml
```
部署机器及宿主机域名解析后，访问`https://kibana.hisun.local/login`

## 9、卸载
### 9.1 卸载kibana
```
kubectl delete -f kibana_es.yaml -n elastic-system
```

### 9.2 卸载 es 应用
```
kubectl delete -f elasticsearch.yaml -n elastic-system
```

### 9.3 卸载 es-operator
``` 
helm uninstall elastic-operator  -n elastic-system  
```

## 参考资料
- [Elastic cloud on k8s (ECK) 部署](https://github.com/elastic/cloud-on-k8s)
- [Install ECK using the Helm chart](https://www.elastic.co/guide/en/cloud-on-k8s/1.3/k8s-install-helm.html)
- [Run Kibana on ECK](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-kibana.html)
- [note-eck](https://github.com/ss75710541/openshift-docs/blob/master/logging/openshift3.11%E4%B8%AD%E4%BD%BF%E7%94%A8ECK%E5%AE%89%E8%A3%85filebeat+elasticsearch+kibana%E6%94%B6%E9%9B%86%E6%97%A5%E5%BF%97%E5%88%9D%E6%8E%A2.md)
- [基于K8s部署ECK(Elastic Cloud on Kubernetes)](https://zhuanlan.zhihu.com/p/105453664)
- [如何给ElasticSearch设置用户名和密码](https://zhuanlan.zhihu.com/p/163337278)

