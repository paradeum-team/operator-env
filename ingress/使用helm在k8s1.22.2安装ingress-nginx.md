# 使用helm在k8s1.22.2安装ingress-nginx

## 添加 helm repo

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

## 下载 chart

```
mkdir ~/ingress-nginx
cd ~/ingress-nginx/
helm pull ingress-nginx/ingress-nginx
```

## 创建 values.yaml

参考：https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml

```
controller:
  image:
    registry: registry.hisun.netwarps.com
    image: ingress-nginx/controller
    tag: "v1.0.4"
    digest: ""
    pullPolicy: IfNotPresent
  admissionWebhooks:
    patch:
      image:
        registry: registry.hisun.netwarps.com
        image: ingress-nginx/kube-webhook-certgen
        tag: v1.1.1
        digest: ""
        pullPolicy: IfNotPresent
  kind: DaemonSet
  service:
    externalTrafficPolicy: Local
    type: NodePort
    nodePorts:
      http: 32080
      https: 32443
      tcp:
        8080: 32808
  tolerations:
    - effect: NoSchedule
      operator: Exists
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role.kubernetes.io/master
            operator: Exists
```

## 部署

```
helm upgrade --install ingress-nginx ingress-nginx-4.0.6.tgz -f values.yaml -n ingress-nginx --create-namespace
```