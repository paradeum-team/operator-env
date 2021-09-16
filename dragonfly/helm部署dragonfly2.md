# helm部署 dragonfly2

## 下载 chart

```
mkdir -p ~/dragonfly
cd ~/dragonfly
helm repo add dragonfly https://dragonflyoss.github.io/helm-charts/
helm pull dragonfly/dragonfly
```


## 创建 values.yaml

参考：https://github.com/dragonflyoss/helm-charts/blob/5ea8bb527e6ae113837e7ed81e312c9467942639/charts/dragonfly/values.yaml

```
scheduler:
  replicas: 1
  nodeSelector:
    kubernetes.io/hostname: node1.solarfs.k8s
cdn:
  replicas: 2
  resources:
    requests:
      cpu: "0"
      memory: "0"
    limits:
      cpu: "2"
      memory: "4Gi"
#  nodeSelector:
#    kubernetes.io/hostname: node1.solarfs.k8s
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: component
              operator: In
              values:
              - cdn
          topologyKey: kubernetes.io/hostname
manager:
  replicas: 1
  nodeSelector:
    kubernetes.io/hostname: node1.solarfs.k8s

containerRuntime:
  docker:
    enable: true
    restart: true

dfdaemon:
  enable: true
  hostNetwork: true
  config:
    proxy:
      registryMirror:
        url: "https://registry.hisun.netwarps.com"
      hijackHTTPS:
        hosts:
        - regx: .*
          insecure: true
```

执行安装

```
helm upgrade --install --create-namespace --namespace dragonfly-system dragonfly dragonfly-0.5.2.tgz -f values.yaml
```


