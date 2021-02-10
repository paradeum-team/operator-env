# k8s安装weave-scope

## 简介

Weave Scope - Docker & Kubernetes的故障排除和监控

## 下载镜像到私有仓库

```
docker.io/weaveworks/scope:1.13.1
```

## 安装

下载安装 yaml

```
curl -L -o scope.yaml "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

```
sed -i 's/docker.io/registry.hisun.netwarps.com/g' scope.yaml
```

```
kubectl apply -f scope.yaml
```

创建 ingress 文件

```
cat >scope-ingress.yaml<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: weave-scope
  namespace: weave
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: weave-scope.apps164103.hisun.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: weave-scope-app
            port:
              number: 80
EOF
```

部署 scope ingress

```
kubectl apply -f scope-ingress.yaml
```

weave-scope.apps164103.hisun.local 解析到 ingress 主机 ip

访问 

```
http://weave-scope.apps164103.hisun.local
```

参考：

https://www.weave.works/docs/scope/latest/installing/#k8s