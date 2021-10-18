# helm安装cmak-operator(cmak以前叫kafka manager)

## 添加 chart repo

```
helm repo add cmak https://eshepelyuk.github.io/cmak-operator
helm repo update
```

## 下载 chart

```
helm pull cmak/cmak-operator
```

## 安装


注意：cmak-operator 在 k8s 1.22.2 中 ingress 相关配置 kind 版本太低，所以，放弃在 values.yaml 中配置 ingess , k8s 1.21 之前的版本可以尝试使用

```
helm upgrade --install --create-namespace -n cmak-ns cmak cmak-operator-1.6.1.tgz
```

## 创建 ingress

ingress.yaml

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: cmak
  namespace: cmak-ns
spec:
  rules:
  - host: cmak.apps92250.hisun.k8s
    http:
      paths:
      - backend:
          service:
            name: cmak
            port:
              number: 9000
        path: /
        pathType: Prefix
```

```
kubectl apply -f ingress.yaml
```

## 访问

解析 cmak.apps92250.hisun.k8s 到 ingress ip

访问

```
cmak.apps92250.hisun.k8s
```

## 参考

https://github.com/eshepelyuk/cmak-operator
