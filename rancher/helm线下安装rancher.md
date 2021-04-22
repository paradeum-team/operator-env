# helm线下安装rancher

## 拉取镜像到私有仓库

```
rancher/rancher:v2.5.7
rancher/shell:v0.1.6
rancher/rancher-webhook:v0.1.0-beta9
rancher/fleet:v0.3.4
rancher/gitjob:v0.1.13
rancher/fleet-agent:v0.3.4
rancher/rancher-operator:v0.1.3
```

## 安装 cert-manager

参考: [线下安装cert-manager.md](https://github.com/paradeum-team/operator-env/blob/main/cert-manager/%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85cert-manager.md)

## 添加 helm repo, 下载 chart

```
# 添加 repo
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
# 更新 repo
helm repo update
# 下载 最新 rancher chart
helm fetch rancher-stable/rancher
```

## 根据模板生成发布文件

生成发布文件

注意：这里replicas 设置为1，是为了高可用 k8s 1.21.0 环境连接不上命令行修改的，如果不需要连接命令行，可以按默认设置3

```
helm template rancher ./rancher-2.5.7.tgz --output-dir . \
--namespace cattle-system \
--set hostname=rancher.apps181227.hisun.k8s \
--set certmanager.version=v1.3.1 \
--set rancherImage=registry.hisun.netwarps.com/rancher/rancher \
--set systemDefaultRegistry=registry.hisun.netwarps.com \
--set replicas=1 \
--set useBundledSystemChart=true
```

因为当前环境安装的 cert-manager 为 v1.3.1, 所以需要修改 `issuer-rancher.yaml` 中 `apiVersion`

```
sed -i 's#apiVersion:.*#apiVersion: cert-manager.io/v1#g' rancher/templates/issuer-rancher.yaml
```


## 部署 rancher

```
kubectl create namespace cattle-system
kubectl -n cattle-system apply -R -f ./rancher
```

## 访问

### 解析 `rancher.apps164103.hisun.k8s`
略

### 访问 `https://rancher.apps164103.hisun.k8s`

## 异常处理

### 警告: 组件 controller-manager 不健康

注释下面文件中 `--port=0` 配置
 
```
/etc/kubernetes/manifests/kube-controller-manager.yaml
/etc/kubernetes/manifests/kube-scheduler.yaml
```

重启 kubelet

```
systemctl restart kubelet
```

### web 页面不能进入 kubectl 命令行

查看 rancher 日志报错

```
2021/04/21 08:30:17 [ERROR] Failed to connect to peer wss://10.128.3.53/v3/connect [local ID=10.128.4.36]: websocket: bad handshake
2021/04/21 08:30:17 [ERROR] Failed to connect to peer wss://10.128.5.44/v3/connect [local ID=10.128.4.36]: websocket: bad handshake
2021/04/21 08:30:22 [ERROR] Failed to connect to peer wss://10.128.3.53/v3/connect [local ID=10.128.4.36]: websocket: bad handshake
2021/04/21 08:30:22 [ERROR] Failed to connect to peer wss://10.128.5.44/v3/connect [local ID=10.128.4.36]: websocket: bad handshake
```

所以在 helm 安装时修改副本数为1

···
--set replicas=1 \
···

## 参考 

https://docs.rancher.cn/docs/rancher2.5/installation/install-rancher-on-k8s/_index