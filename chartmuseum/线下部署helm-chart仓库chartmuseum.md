# 线下部署 helm chart 仓库 chartmuseum

参考：

https://artifacthub.io/packages/helm/chartmuseum/chartmuseum

https://github.com/helm/chartmuseum

https://github.com/chartmuseum/charts/tree/main/src/chartmuseum


## 下载镜像到私有仓库

```
ghcr.io/helm/chartmuseum:v0.13.1
```

## 添加 chart repo, 下载 chart

```
helm repo add chartmuseum https://chartmuseum.github.io/charts
helm pull chartmuseum/chartmuseum --version 3.1.0
```

## 创建自定义变量文件

创建 namespace, 创建基础账号密码 secret, 示例为简单密码，请根据实际情况修改 

```
kubectl create namespace chartmuseum
kubectl create secret generic chartmuseum-secret --from-literal="basic-auth-user=admin" --from-literal="basic-auth-pass=12345678" -n chartmuseum
```

```
cat>values.yaml<<EOF
image:
  repository: registry.hisun.netwarps.com/helm/chartmuseum
  tag: v0.13.1
env:
  open:
    STORAGE: local
    DISABLE_API: false
    DEPTH: 0
  existingSecret: chartmuseum-secret
  existingSecretMappings:
    BASIC_AUTH_USER: basic-auth-user
    BASIC_AUTH_PASS: basic-auth-pass
persistence:
  enabled: true
  accessMode: ReadWriteMany
  size: 8Gi
  storageClass: nfs3-client
replicaCount: 2
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
  - name: charts.apps181227.hisun.k8s
    tls: true
EOF
```

## 执行安装 chartmuseum

```
helm install chartmuseum  -f values.yaml -n chartmuseum chartmuseum-3.1.0.tgz
```

## 默认 禁用了 chartmuseum api操作安装 helm-push 插件

```
wget https://github.com/chartmuseum/helm-push/releases/download/v0.9.0/helm-push_0.9.0_linux_amd64.tar.gz
```

查看 helm 插件目录

```
helm env|grep HELM_PLUGINS

HELM_PLUGINS="/root/.local/share/helm/plugins"
```

创建 helm-push 插件目录，并 解压插件到目录

```
mkdir -p /root/.local/share/helm/plugins/helm-push
tar xzvf helm-push_0.9.0_linux_amd64.tar.gz -C /root/.local/share/helm/plugins/helm-push/
```

集群内添加 使用 svc 添加 helm repo chartmuseum-hisun

```
helm repo add chartmuseum-hisun http://chartmuseum.chartmuseum.svc:8080 --username admin --password 12345678
```

集群外部使用 ingress 地址添加 helm repo chartmuseum-hisun（暂时不用）

```
helm repo add  chartmuseum-hisun https://charts.apps181227.hisun.k8s --username admin --password 12345678 --insecure-skip-tls-verify
```

推送 chart 到 chartmuseum-hisun

```
helm push chartmuseum-3.1.0.tgz chartmuseum-hisun
```