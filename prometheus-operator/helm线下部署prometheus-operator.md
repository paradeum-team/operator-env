# helm线下部署prometheus-operator

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
```


```
docker.io/jettech/kube-webhook-certgen:v1.5.0
docker.io/grafana/grafana:7.3.5
quay.io/prometheus/alertmanager:v0.21.0
quay.io/prometheus-operator/prometheus-operator:v0.45.0
quay.io/prometheus-operator/prometheus-config-reloader:v0.45.0
quay.io/prometheus/prometheus:v2.24.0
quay.io/prometheus/node-exporter:v1.0.1
docker.io/curlimages/curl:7.73.0
docker.io/library/busybox:1.31.1
docker.io/kiwigrid/k8s-sidecar:1.1.0
```

## 下载chart

```
helm pull prometheus-community/kube-prometheus-stack --version 13.0.2
```

## 创建 namespace

```
kubectl create namespace monitoring
```

## 创建`values.yaml`文件

```
#修改

# 域名后缀
domain="apps164103.hisun.local"
# 私有镜像仓库地址
repository="registry.hisun.netwarps.com"


#执行创建 values 命令
cat <<EOF > kube-prometheus-stack-values.yaml
alertmanager:
  ingress:
    enabled: true
    hosts: ["alertmanager.${domain}"]
  alertmanagerSpec:
    image:
      repository: ${repository}/prometheus/alertmanager
    replicas: 1
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
    hosts: ["grafana.${domain}"]
  replicas: 1
  image:
    repository: ${repository}/grafana/grafana
  initChownData:
    image: ${repository}/library/busybox
  downloadDashboardsImage:
    repository: ${repository}/curlimages/curl
  sidecar:
    image:
      repository: ${repository}/kiwigrid/k8s-sidecar
prometheusOperator:
  admissionWebhooks:
    patch:
      enabled: true
      image:
        repository: ${repository}/jettech/kube-webhook-certgen
  image:
    repository: ${repository}/prometheus-operator/prometheus-operator
  prometheusConfigReloaderImage:
    repository: ${repository}/prometheus-operator/prometheus-config-reloader
prometheus:
  ingress:
    enabled: true
    hosts: ["prometheus.${domain}"]
  prometheusSpec:
    replicas: 1
    image:
      repository: ${repository}/prometheus/prometheus
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
    repository: ${repository}/prometheus/node-exporter
EOF
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
helm install prometheus-community kube-prometheus-stack-13.0.2.tgz -f kube-prometheus-stack-values.yaml -n  monitoring
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
helm upgrade prometheus-community kube-prometheus-stack-13.0.2.tgz -f kube-prometheus-stack-values.yaml -n  monitoring
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

```
http://grafana.apps164103.hisun.local/
```

## 卸载promehteus-operator相关服务

```
helm uninstall prometheus-community -n  monitoring
```
