# 说明
在k8s集群上使用kafka的operator 来安装kafka集群。

欲搭建kafka 环境，需要先搭建kafka的依赖的环境。

依赖如下：

- cert-manager
	- **0.15.x:** Kafka operator 0.8.x and newer supports cert-manager 0.15.x
	- **0.10.x:** Kafka operator 0.7.x supports cert-manager 0.10.x
- zookeeper
- Prometheus


## 1、Install cert-manager
由于网络问题，建议使用yaml方式安装。默认部署到 namespace 为`cert-manager`下

### 1.1 使用yaml 方式安装
```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.yaml

```

### 1.2 使用helm 方式安装
```
# Add the jetstack helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager into the cluster
# Using helm3
helm install cert-manager --namespace cert-manager --create-namespace --version v0.15.1 jetstack/cert-manager
# Using previous versions of helm
helm install --name cert-manager --namespace cert-manager --version v0.15.1 jetstack/cert-manager
  
# Install the CustomResourceDefinitions
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.1/cert-manager.crds.yaml
```


## 参考文档
- [banzaicloud/kafka-operator 源码](https://github.com/banzaicloud/kafka-operator)
- [kafka-operator 安装文档](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)
- [pravega/zookeeper-operator 源码及docs](https://github.com/pravega/zookeeper-operator)
- [prometheus-operator文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)
- [基础环境与网络](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

