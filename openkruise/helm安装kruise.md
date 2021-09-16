# helm安装kruise

## 下载 chart

```
mkdir ~/kriuse
cd ~/kriuse
wget https://github.com/openkruise/kruise/releases/download/v0.10.0/kruise-chart.tgz
```

## 解压并修改 chart

```
tar xzvf kruise-chart.tgz
```

修改 kruise/templates/rbac_role.yaml

```
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
```

## 安装

```
helm upgrade --install kruise kruise -n kruise-system --create-namespace
```

## 使用预热

创建 rnode-pkg-job.yaml

```
apiVersion: apps.kruise.io/v1alpha1
kind: ImagePullJob
metadata:
  name: rnode-pkg-job
  namespace: bfs
spec:
  image: alpine:3.13   # [required] 完整的镜像名 name:tag
  parallelism: 50      # [optional] 最大并发拉取的节点, 默认为 1
  completionPolicy:
    type: Never # [optional] 默认为 Always
  pullPolicy:                     # [optional] 默认 backoffLimit=3, timeoutSeconds=600
    backoffLimit: 3
    timeoutSeconds: 600
  pullSecrets:
  - cicd-harbor-secret
```

发布预热 job

```
kubectl apply -f  rnode-pkg-job.yaml
```

观察预热进度

```
kubectl get imagepulljobs -n bfs
```

## 参考

https://github.com/openkruise/kruise/blob/master/README-zh_CN.md

https://openkruise.io/zh-cn/docs/imagepulljob.html