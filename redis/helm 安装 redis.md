# helm 安装 redis

## 下载 helm chart

```
mkdir ~/redis
cd ~/redis
helm repo add bitnami https://charts.bitnami.com/bitnami
helm pull bitnami/redis
```

## 创建 values.yaml

参考： https://github.com/bitnami/charts/tree/master/bitnami/redis

```
master:
  nodeSelector:
    kubernetes.io/hostname: "master1.solarfs.k8s"
  tolerations:
    - effect: NoSchedule
      operator: Exists

replica:
  replicaCount: 1
  nodeSelector:
    kubernetes.io/hostname: "master1.solarfs.k8s"
  tolerations:
    - effect: NoSchedule
      operator: Exists
```

## 部署 redis

```
helm upgrade --install redis redis-15.3.2.tgz -n redis-system --create-namespace
```
