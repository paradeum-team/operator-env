# macos 本地搭建k8s环境
在 macos 上安装 docker，然后基于`docker desktop`配置，搭建k8s环境

## 1、安装 docker desktop

- 1. 需安装 Docker Desktop 的 Mac 或者 Windows 版本，如果没有请下载[下载 Docker CE最新版本](https://hub.docker.com/search?type=edition&offering=community)


## 2、启动docker 查看k8s版本
点击[about docker desktop] 打开如下对下框
![](./images/docker-desktop-1.png)
获取k8s 版本如:`v1.19.3`

## 3、拉取 k8s依赖的镜像
克隆依赖镜像，可以按照网站[操作](https://github.com/AliyunContainerService/k8s-for-docker-desktop)

```
git clone git@github.com:AliyunContainerService/k8s-for-docker-desktop.git
```
切换分支到k8s对应版本：`v1.19.3`


```
cd k8s-for-docker-desktop
git checkout -b v1.19.3 origin/v1.19.3


# cat images.properties
# 这里存放的是k8s依赖的镜像
```

**拉取依赖的镜像**

```
cd k8s-for-docker-desktop
./load_images.sh

# docker images
docker/desktop-kubernetes                                        kubernetes-v1.19.3-cni-v0.8.5-critools-v1.17.0   7f85afe431d8   3 months ago    285MB
k8s.gcr.io/kube-proxy                                            v1.19.3                                          cdef7632a242   3 months ago    118MB
k8s.gcr.io/kube-apiserver                                        v1.19.3                                          a301be0cd44b   3 months ago    119MB
k8s.gcr.io/kube-controller-manager                               v1.19.3                                          9b60aca1d818   3 months ago    111MB
k8s.gcr.io/kube-scheduler                                        v1.19.3                                          aaefbfa906bd   3 months ago    45.7MB
k8s.gcr.io/etcd                                                  3.4.13-0                                         0369cf4303ff   4 months ago    253MB
k8s.gcr.io/coredns                                               1.7.0                                            bfe3a36ebd25   7 months ago    45.2MB
docker/desktop-storage-provisioner                               v1.1                                             e704287ce753   9 months ago    41.8MB
docker/desktop-vpnkit-controller                                 v1.0                                             79da37e5a3aa   10 months ago   36.6MB
k8s.gcr.io/pause                                                 3.2                                              80d28bedfe5d   11 months ago   683kB
quay.io/kubernetes-ingress-controller/nginx-ingress-controller   0.26.1                                           29024c9c6e70   15 months ago   483MB
```

## 4、开启配置，启动k8s
勾选如下：

![](./images/docker-desktop-2.png)

然后重启，docker。


## 5、遇到问题：
docker启动了，但是k8s一直卡在starting。主要是原因不明确，据说是版本不对。采用方法，重启docker，k8s等。

## 6、k8s 配置

```
kubectl config use-context docker-desktop
## 验证 Kubernetes 集群状态
kubectl cluster-info
kubectl get nodes
```


## 7、使用
### 7.1 配置k8s控制台


```
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.4/aio/deploy/recommended.yaml

或
kubectl create -f kubernetes-dashboard.yaml

```

检查 kubernetes-dashboard 应用状态

```
kubectl get pod -n kubernetes-dashboard

```

开启 API Server 访问代理

```
kubectl proxy

```

通过如下 URL 访问 Kubernetes dashboard

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```