# 安装 local-path-provisioner

```
wget https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

`local-path-storage.yaml` 默认从docker.io 拉取镜像，可以把image改为私有源地址

默认挂载的本地目录为 `/opt/local-path-provisioner` ,可以修改为 `/data/local-path-provisioner`

部署

```
kubectl apply -f local-path-storage.yaml
```

查看pod 状态

```
kubectl -n local-path-storage get pod
```

查看pod 日志

```
kubectl -n local-path-storage logs -f -l app=local-path-provisioner
```

设置local-path为默认storageclass

```
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

查看 storageclass列表

```
kubectl get storageclass

NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  43h
```
