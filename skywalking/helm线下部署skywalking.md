# 使用helm 部署skywalking

## 1、基础配置
skywalking 部署依赖 elasticSearch部署。 怎么部署es集群，参考[对应文档](https://github.com/paradeum-team/operator-env/blob/main/elasticsearch/helm%20%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85elasticsearch.md)

现在把 es的相关配置需要重建：

### 1.1 创建 namespace
```
kubectl create namespace apm
```

### 1.2、准备https的 tls 认证。
**注意：** 如果es没有开启tls，这里可以略过

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
**注意：**若是密码不挂载，这步也是可以略过

- **账号:** elastic	
- **查看kibana登录密码:**
	 
	```
	kubectl get secret es-base-es-elastic-user -n elastic-system -o=jsonpath='{.data.elastic}' | base64 --decode; echo
	
	#output
	UnI89STQB3Olr926I4Vm5K04
	```
- **创建密码secret:**	
	
	```
	kubectl create secret generic apm-es-elastic-user  --from-literal=elastic=UnI89STQB3Olr926I4Vm5K04 -n apm
	```

### 1.4 准备镜像 并推送到私有仓库
**私有仓库地址：**`registry.hisun.netwarps.com`

**镜像 List:**

- apache/skywalking-oap-server:8.3.0-es7
- apache/skywalking-ui:8.3.0
- docker.elastic.co/elasticsearch/elasticsearch:7.10.2


## 2、下载离线chart
```
git clone https://github.com/apache/skywalking-kubernetes ?
git clone git@github.com:apache/skywalking-kubernetes.git
cd skywalking-kubernetes/chart

# 打包helm的chart
tar -cvf skywalking-v4.0.0.tgz skywalking
```

## 3、部署方式二：使用helm 的skywalking 安装
### 3.1 添加repo，更新repo
```
helm repo add elastic https://helm.elastic.co
helm repo update
```

### 3.2 下载仓库
 `git clone https://github.com/apache/skywalking-kubernetes ?`   
 `git clone git@github.com:apache/skywalking-kubernetes.git`

### 3.3 安装repo
```
cd skywalking-kubernetes/chart
helm repo add elastic https://helm.elastic.co
helm dep up skywalking
```

### 3.4 修改参数：
编辑`./skywalking-oap-server.yaml`，修改参数。尤其是es配置


```
oap:
  image:
    repository: registry.hisun.netwarps.com/apache/skywalking-oap-server
    tag: 8.3.0-es7      # Set the right tag according to the existing Elasticsearch version
  storageType: elasticsearch7

ui:
  image:
    repository: registry.hisun.netwarps.com/apache/skywalking-ui
    tag: 8.3.0

elasticsearch:
  enabled: false
  config:               # For users of an existing elasticsearch cluster,takes effect when `elasticsearch.enabled` is false
    host: your.elasticsearch.host.or.ip #[need replace]
    port:
      http: 9200
    user: "elastic"         # [optional]
    password: "UnI89STQB3Olr926I4Vm5K04"     # [optional]
```

### 3.5 执行安装
- 方式一：
```
helm install apm-skywalking skywalking-v4.0.0.tgz -n apm -f skywalking-oap-server.yaml
```

- 方式二：解压 skywalking-v4.0.0.tgz

```
helm repo add elastic https://helm.elastic.co
helm dep up skywalking

helm install apm-skywalking skywalking -n apm -f skywalking-oap-server.yaml
```


### 3.6 卸载: 
`helm uninstall apm-skywalking -n apm`

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
  # or 
  kubectl port-forward svc/apm-skywalking-ui -n apm 8080:80
```


## 参考资料
- [elastic-apm](https://github.com/elastic/apm)
- [apm-server](https://github.com/elastic/helm-charts/blob/master/apm-server/examples/security/values.yaml)
- [skywalking-k8s 部署](https://github.com/apache/skywalking-kubernetes/blob/master/README.md)
- [Skywalking 通过 HTTPS SSL 认证连接](https://skywalking-handbook.netlify.app/extensions/es_https/)
- [k8s 中文文档 ](http://docs.kubernetes.org.cn/468.html)
- [apm系统性能](https://skywalking-handbook.netlify.app/installation/container_way/)
