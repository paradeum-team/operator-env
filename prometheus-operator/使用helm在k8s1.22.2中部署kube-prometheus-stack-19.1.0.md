# 使用helm在k8s1.22.2中部署kube-prometheus-stack-19.1.0

### 添加 repo, 更新repo 信息

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

### 查看所有可配置选项的详细注释

使用命令查看

```
helm show values prometheus-community/kube-prometheus-stack
```

或 访问github 地址查看

```
https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
```
## 下载相关镜像到 私有仓库

镜像地址从下面values.yaml中查找 `repository` 

```
https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-node-exporter/values.yaml
https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/values.yaml
```


```
k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.0
docker.io/grafana/grafana:8.1.5
docker.io/bats/bats:v1.1.0
quay.io/prometheus/alertmanager:v0.22.2
quay.io/prometheus-operator/prometheus-operator:v0.50.0
quay.io/prometheus-operator/prometheus-config-reloader:v0.50.0
quay.io/thanos/thanos:v0.17.2
quay.io/prometheus/prometheus:v2.28.1
docker.io/curlimages/curl:7.73.0
docker.io/library/busybox:1.31.1
quay.io/kiwigrid/k8s-sidecar:1.12.3
quay.io/prometheus/node-exporter:v1.2.2
k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.2.0
```

## 下载chart

```
helm pull prometheus-community/kube-prometheus-stack --version 19.1.0
```

## 创建 namespace

```
kubectl create namespace monitoring
```

## 创建`values.yaml`文件

酌情修改 

- ingress 中 hosts
- image 中 repository 参数 
- storageClassName 参数

```
alertmanager:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts: ["alertmanager.apps92250.hisun.k8s"]
    pathType: ImplementationSpecific
  alertmanagerSpec:
    image:
      repository: registry.hisun.netwarps.com/prometheus/alertmanager
    replicas: 2
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 1Gi
grafana:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts: ["grafana.apps92250.hisun.k8s"]
    pathType: ImplementationSpecific
  replicas: 1
  grafana.ini:
    paths:
      data: /var/lib/grafana/
      logs: /var/log/grafana
      plugins: /mnt # 自定义镜像插件安装到此目录, 修改插件目录是为了自定义镜像中的插件不被覆盖
      provisioning: /etc/grafana/provisioning
    analytics:
      check_for_updates: true
    log:
      mode: console
    grafana_net:
      url: https://grafana.net
  persistence:
    enabled: true
    storageClassName: "nfs4-client"
    size: 1Gi
  image:
    repository: registry.hisun.netwarps.com/grafana/grafana
    tag: 8.3.7-custom.1 # 自定义镜像
  initChownData:
    image:
      repository: registry.hisun.netwarps.com/library/busybox
      tag: "1.31.1"
  downloadDashboardsImage:
    repository: registry.hisun.netwarps.com/curlimages/curl
  sidecar:
    image:
      repository: registry.hisun.netwarps.com/kiwigrid/k8s-sidecar
prometheusOperator:
  admissionWebhooks:
    patch:
      enabled: true
      image:
        repository: registry.hisun.netwarps.com/ingress-nginx/kube-webhook-certgen
        tag: v1.1.1
        sha: ""
  image:
    repository: registry.hisun.netwarps.com/prometheus-operator/prometheus-operator
  prometheusConfigReloaderImage:
    repository: registry.hisun.netwarps.com/prometheus-operator/prometheus-config-reloader
prometheus:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts: ["prometheus.apps92250.hisun.k8s"]
    pathType: ImplementationSpecific
  prometheusSpec:
    replicas: 2
    image:
      repository: registry.hisun.netwarps.com/prometheus/prometheus
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: local-path
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
prometheus-node-exporter:
  image:
    repository: registry.hisun.netwarps.com/prometheus/node-exporter
kube-state-metrics:
  image:
    repository: registry.hisun.netwarps.com/kube-state-metrics/kube-state-metrics
kubeEtcd:
  service:
    port: 2381
    targetPort: 2381
```

## 执行部署

helm install 语法

```
Usage:
  helm install -f myvalues.yaml [NAME] [CHART] [flags]
```

其中 `install` 后面跟的 `prometheus-community` 为自定义的 `NAME`

使用已经下载的 kube-prometheus-stack chart包安装

```
helm upgrade --install prometheus-community kube-prometheus-stack-19.1.0.tgz -f kube-prometheus-stack-values.yaml -n  monitoring --create-namespace
```

## 更新已部署服务

可以下载新版本 charts 包，或修改 values.yaml 进行更新

helm upgrade 语法

```
Usage:
  helm upgrade [RELEASE] [CHART] [flags]
```

使用修改后的`values.yaml`更新服务

```
helm upgrade --install prometheus-community kube-prometheus-stack-19.1.0.tgz -f kube-prometheus-stack-values.yaml -n  monitoring --create-namespace
```
## 查看 helm 部署的 charts

```
helm ls -n monitoring
```

## 查看 prometheus-operator 相关pod 状态

```
kubectl --namespace monitoring get pods
```

## 查看 grafana 登录用户密码

```
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-user:"|awk '{print $2}'|base64 -d
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-password:"|awk '{print $2}'|base64 -d
```

## 访问grafana

解析域名到 ingress 或 ingress 前面的 LB ip

```
http://grafana.apps92250.hisun.k8s/
```

## 卸载promehteus-operator相关服务

```
helm uninstall prometheus-community -n  monitoring
```

## 故障处理

### kubelet metrics down

#### 问题描述

查看 prometheus Status --> Targets --> monitoring/prometheus-community-kube-kubelet/0 


其中一项 endpoint metrics 报错 访问 `https://172.26.164.105:10250/metrics` 报下面错误

```
server returned HTTP status 401 Unauthorized
```

#### 故障原因：

怀疑是客户端证书不同步，重启下自动同步

#### 解决方法：

重启 172.26.164.105 主机后恢复

### kube-proxy metrics down

#### 问题描述

查看 prometheus Status --> Targets --> `monitoring/prometheus-community-kube-kube-proxy/0` 

endpoint 监控列表所有 metrics 都报错

```
Get "http://172.26.164.103:10249/metrics": dial tcp 172.26.164.103:10249: connect: connection refused
```

##### 问题原因：

kube-proxy metrics 默认监听 ip 为 127.0.0.1

##### 问题解决：

1、使用 kubeadm 安装k8s 前修改 `kubeadm-init.yaml`，再安装 k8s

找到 `KubeProxyConfiguration ` 相关配置，修改`metricsBindAddress` 值如下

```
...
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
metricsBindAddress: 0.0.0.0:10249
...
```

2、已经安装好 k8s 的环境操作如下

编辑  configmap kube-proxy

```
kubectl edit cm kube-proxy -n kube-system
```

找到 `metricsBindAddress` 修改值如下

```
    metricsBindAddress: "0.0.0.0:10249"
```

重启 `kube-proxy`

```
kubectl rollout restart ds kube-proxy -n kube-system
```

查看 pod 状态

```
kubectl get pod -l k8s-app=kube-proxy -n kube-system
```

### kube-etcd metrics down

#### 问题描述

查看 prometheus Status --> Targets --> `monitoring/prometheus-community-kube-kube-etcd/0`

endpoint 监控列表所有 metrics 都报错

```
Get "http://172.26.164.103:2379/metrics": read tcp 10.128.1.22:58320->172.26.164.103:2379: read: connection reset by peer
```

#### 故障原因：

原因是新版本 K8s etcd metrics 换了监控端口

#### 故障解决：

##### 修改 etcd metrics 监控 ip

1、使用 kubeadm 工具 在安装k8s前

修改 `kubeadm-init.yaml`

修改 etcd listen-metrics-urls 配置如下

```
etcd:
  local:
    dataDir: /var/lib/etcd
    ExtraArgs:
      listen-metrics-urls=http://0.0.0.0:2381
```

2、已经安装好 k8s 的操作如下

修改所有 master 主机`/etc/kubernetes/manifests/etcd.yaml`

找到 `listen-metrics-urls` 配置，

```
spec:
  containers:
  - command:
      ...
      - --listen-metrics-urls=http://0.0.0.0:2381
      ...
```

修改完成后保存，etcd 会自动重启

查看 etcd 容器状态

```
docker ps -a|grep etcd
```

测试访问 etcd metrics

```
curl http://172.26.164.103:2381/metrics
```

##### 已经使用 helm 安装好的 prometheus-operator 的，如果操作如下

在 helm 安装 prometheus-operator  的 `kube-prometheus-stack-values.yaml` 最下方添加如下内容

```
kubeEtcd:
  service:
    port: 2381
    targetPort: 2381
```

执行更新 prometheus-operator helm

```
helm upgrade --install prometheus-community kube-prometheus-stack-19.1.0.tgz -f kube-prometheus-stack-values.yaml -n  monitoring --create-namespace
```

### kube-controller-manager metrics down 

访问 `http://prometheus.apps92250.hisun.k8s/targets` 显示如下：

```
serviceMonitor/monitoring/prometheus-community-kube-kube-controller-manager/0 (0/3 up)
```

```
Get "http://172.16.94.181:10252/metrics": dial tcp 172.16.94.181:10252: connect: connection refused
```

原因是因为安全问题，默认禁用了访问端口，目前暂时没有处理，后面查一下资料再处理

### kube-kube-scheduler metrics down

访问 `http://prometheus.apps92250.hisun.k8s/targets` 显示如下：

```
serviceMonitor/monitoring/prometheus-community-kube-kube-scheduler/0 (0/3 up)
```

```
Get "http://172.16.188.11:10251/metrics": dial tcp 172.16.188.11:10251: connect: connection refused
```

原因是因为安全问题，默认禁用了访问端口，目前暂时没有处理，后面查一下资料再处理