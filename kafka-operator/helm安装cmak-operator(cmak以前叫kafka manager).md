# helm安装cmak-operator(cmak以前叫kafka manager)

## 添加 chart repo

```
helm repo add cmak https://eshepelyuk.github.io/cmak-operator
helm update
```

## 下载 chart

```
helm pull cmak/cmak-operator
```

## 创建 values.yaml

```
ingress:
  host: cmak.apps181227.hisun.k8s
  path: /
```

## 安装

```
helm upgrade --install --create-namespace -n cmak-ns cmak cmak-operator-1.6.1.tgz -f values.yaml
```

## 访问

解析 cmak.apps181227.hisun.k8s 到 ingress ip

访问

```
cmak.apps181227.hisun.k8s
```

## 参考

https://github.com/eshepelyuk/cmak-operator
