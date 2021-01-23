# kafka and zk 
在k8s集群上使用kafka的operator 来安装kafka集群。

欲搭建kafka 环境，需要先搭建kafka的依赖的环境。

依赖如下：

- cert-manager
	- **0.15.x:** Kafka operator 0.8.x and newer supports cert-manager 0.15.x
	- **0.10.x:** Kafka operator 0.7.x supports cert-manager 0.10.x
- zookeeper
- Prometheus


# install prometheus-operator

有两种方式安装。

[参考文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)

### 3.1 install with helm 方式


#### 3.1.1  添加 repo, 更新repo 信息

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

#### 3.1.2  查看所有可配置选项的详细注释

```
helm show values prometheus-community/kube-prometheus-stack
```

#### 3.1.3  部署prometheus-operator

mac 环境node-exporter因不存在`/var/log/pods`目录运行失败，所以禁用

```
kubectl create namespace monitoring
helm install prometheus-community prometheus-community/kube-prometheus-stack -n  monitoring \
--set nodeExporter.enabled=false
```

查看 helm 部署的 chart

```
helm ls -n monitoring
```

查看 prometheus-operator 相关pod 状态

```
kubectl get pod -n monitoring
```

#### 3.1.4 使用port-forward转发grafana服务端口，提供访问入口

```
kubectl port-forward svc/prometheus-community-grafana 3000:80 -n monitoring
```

查看 grafana 登录用户密码

```
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-user:"|awk '{print $2}'|base64 -d
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-password:"|awk '{print $2}'|base64 -d
```

通过访问 http://127.0.0.1:3000 访问grafana


#### 3.1.5 卸载 prometheus-community

```
helm uninstall prometheus-community -n monitoring
```

## 参考文档
- [banzaicloud/kafka-operator 源码](https://github.com/banzaicloud/kafka-operator)
- [kafka-operator 安装文档](https://banzaicloud.com/docs/supertubes/kafka-operator/install-kafka-operator/)
- [pravega/zookeeper-operator 源码及docs](https://github.com/pravega/zookeeper-operator)
- [prometheus-operator文档](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/Mac-docker-kubenetes-helm3%E5%AE%89%E8%A3%85prometheus-operator.md)
- [基础环境与网络](https://github.com/paradeum-team/operator-env/blob/main/docker-k8s-env/macos%20%E6%9C%AC%E5%9C%B0%E6%90%AD%E5%BB%BAk8s%E7%8E%AF%E5%A2%83.md)

