# elasticsearch operator 部署

----

## 1 添加repo，更新repo

```
helm repo add elastic https://helm.elastic.co
helm repo update
```

## 2 查看vlaues.yaml配置信息
使用命令查看

```
helm show values elastic/eck-operator
```

或者直接查看文件

 ```
 https://github.com/elastic/cloud-on-k8s/blob/master/deploy/eck-operator/values.yaml
 ```

## 3  下载相关镜像到 私有仓库
**镜像 List:**

- docker.elastic.co/eck/eck-operator:1.3.1
- docker.elastic.co/elasticsearch/elasticsearch:7.10.2
- docker.elastic.co/kibana/kibana:7.10.2

## 4 下载chart 

```
helm pull elastic/eck-operator
```

## 5 创建 namespace
```
kubectl create namespace elastic-system
```

## 6 自定义values.yaml

todo 

## 7 执行部署
### 7.1  默认部署(线上镜像)
#### 方式一：Cluster-wide (global) installationedit：

This is the default mode of installation and is equivalent to installing ECK using the all-in-one.yaml file.

```
helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace
```

#### 方式二：Restricted installationedit
This mode avoids installing any cluster-scoped resources and restricts the operator to manage only a set of pre-defined namespaces.

Since CRDs are global resources, they still need to be installed by an administrator. This can be achieved by:

```
helm install elastic-operator-crds elastic/eck-operator-crds
```

The operator can be installed by any user who has full access to the set of namespaces they wish to manage. The following example installs the operator to elastic-system namespace and configures it to manage only **`namespace-a`** and **`namespace-b`**:

```
helm install elastic-operator elastic/eck-operator -n elastic-system --create-namespace \
  --set=installCRDs=false \
  --set=managedNamespaces='{namespace-a, namespace-b}' \
  --set=createClusterScopedResources=false \
  --set=webhook.enabled=false \
  --set=config.validateStorageClass=false
```


### 7.2 离线chart 部署

```
helm install elastic-operator eck-operator-1.3.1.tgz -n elastic-system  \
--set webhook.enabled=true \
--set image.repository=registry.hisun.netwarps.com/eck/eck-operator 
```


## 8 更新部署



## 9 部署elastic 实例
### 方式一 [HTTP settings and TLS SANsedit](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-http-settings-tls-sans.html)
**模板文件--1 (master-slave分开)：** elasticsearch.yaml

```
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 7.10.2
  http:
    service:
      spec:
        selector:
          elasticsearch.k8s.elastic.co/cluster-name: "quickstart"
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

**模板文件--2 (master-slave 混合)：** elasticsearch.yaml

```
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 7.10.2
  http:
    service:
      spec:
        type: LoadBalancer
  nodeSets:
  - name: default
    count: 3

```


**命令执行:** 这是使用模板2

```
kubectl apply -f elasticsearch.yaml -n elastic-system
```


### 方式二

由于elastic 没有helm ，所有部署的时候需要使用yaml 方式

模板：`https://github.com/elastic/cloud-on-k8s/blob/master/config/samples/elasticsearch/elasticsearch.yaml`

默认配置是：内存 4G，三个实例，不开启 secret 认证

```
kubectl apply -f elasticsearch.yaml -n elastic-system
```

##  10 查看部署 以及pod 状态
```
kubectl --namespace elastic-system get pods

```

##  11  访问，验证
### 11.1 部署kibana
### 方式一[Elasticsearch is managed by ECK](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-kibana-es.html#k8s-kibana-eck-managed-es)
模板文件：kibana_es.yaml

```
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
spec:
  version: 7.10.2
  count: 1
  elasticsearchRef:
    name: quickstart
    namespace: elastic-system
```

The use of `namespace` is optional if the Elasticsearch cluster is running in the same namespace as Kibana.


**执行命令：**

```
kubectl apply -f kibana_es.yaml -n elastic-system
```

### 方式二
 模板： `https://github.com/elastic/cloud-on-k8s/blob/master/config/samples/kibana/kibana_es.yaml`
 
```
kubectl apply -f kibana_es.yaml -n elastic-system
```

### 11.2 访问
端口本地暴露：

```
kubectl port-forward svc/kibana-quickstart-kb-http -n elastic-system 5601:5601
```

**账号:** elastic

**查看kibana登录密码:**
 
```
kubectl get secret quickstart-es-elastic-user -n elastic-system -o=jsonpath='{.data.elastic}' | base64 --decode; echo
```


**访问：** `https://localhost:5601/login`


## 参考资料
- [Elastic cloud on k8s (ECK) 部署](https://github.com/elastic/cloud-on-k8s)
- [Install ECK using the Helm chart](https://www.elastic.co/guide/en/cloud-on-k8s/1.3/k8s-install-helm.html)
- [Run Kibana on ECK](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-kibana.html)



