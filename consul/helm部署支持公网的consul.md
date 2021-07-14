# helm部署支持公网的consul
## 下载镜像到私有仓库

```
hashicorp/consul:1.9.4
hashicorp/consul-k8s:0.25.0
envoyproxy/envoy-alpine:v1.16.0
```

## 下载 chart

```
curl https://pnode.solarfs.io/dn/file/173fb18bf119b01ae2c5fe2af315425a-consul-0.31.1-1.tgz -o consul-0.31.1-1.tgz
```

## 创建 values.yaml

参考：https://github.com/paradeum-team/consul-helm/blob/consul-public-network/values.yaml


```
mkdir -p ~/consul
cd ~/consul

# 酌情修改下面 nodes 内容
cat >values.yaml<<EOF
global:
  image: "registry.hisun.netwarps.com/hashicorp/consul:1.9.4"

  tls:
    enabled: true
    enableAutoEncrypt: true

  publicNetwork:
    enabled: true
    nodes:
      server:
        - ip: "172.26.181.236"
          advertise: "x.x.x.x"
        - ip: "172.26.181.237"
          advertise: "x.x.x.x"
        - ip: "172.26.181.238"
          advertise: "x.x.x.x"
      client:
        - ip: "172.26.181.240"
          advertise: "x.x.x.x"
        - ip: "172.26.117.95"
          advertise: "x.x.x.x"
        - ip: "172.31.222.173"
          advertise: "x.x.x.x"

server:
  hostNetwork: true
  storageClass: local-path
  exposeGossipAndRPCPorts: true
  nodeSelector: |
    node-role.kubernetes.io/master: ""
  tolerations: |
    - key: "node-role.kubernetes.io/master"
      operator: "Exists"
      effect: "NoSchedule"

client:
  enabled: true
  hostNetwork: true
  exposeGossipPorts: true
  tolerations: |
    - key: "bfs/public-node"
      operator: "Exists"
      effect: "NoSchedule"
EOF
```

## 部署

```
helm upgrade consul --install consul -f values.yaml -n consul-system --create-namespace
```
