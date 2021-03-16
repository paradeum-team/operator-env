# CentOS7.9-安装k8s-1.20.2

## 所有主机设置域名解析

```
cat <<EOF | sudo tee -a /etc/hosts
172.26.164.100 registry.hisun.netwarps.com
172.26.164.103 master164-103 master164-103
172.26.164.104 node164-104 node164-104
EOF
```

主机配置好对应主机名和解析

```
hostnamectl set-hostname master164-103
hostnamectl set-hostname node164-104
```


## 禁用firewalld

```
systemctl disable firewalld --now
iptables -t nat -F && iptables -t mangle -F
```

## 安装容器运行时

### 所有节点安装Docker

```
# (安装 Docker CE)
## 设置仓库
### 安装所需包
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

### 新增 Docker 仓库
sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  
## 安装 Docker CE
sudo yum update -y && sudo yum install -y \
  containerd.io-1.2.13 \
  docker-ce-19.03.11 \
  docker-ce-cli-19.03.11
  
## 创建 /etc/docker 目录
sudo mkdir /etc/docker

# 设置 Docker daemon
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://registry.hisun.netwarps.com"
  ]
}
EOF

# Create /etc/systemd/system/docker.service.d
sudo mkdir -p /etc/systemd/system/docker.service.d

# 启动 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
# 开机启动 docker
sudo systemctl enable docker --now
```


## 所有节点安装 kubeadm、kubelet 和 kubectl

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# 将 SELinux 设置为 permissive 模式（相当于将其禁用）
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 安装节点 kubelet kubeadm kubectl
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 默认配置的pause镜像使用gcr.io仓库，国内可能无法访问，所以这里配置Kubelet使用私有仓库的pause镜像：
cat >/etc/sysconfig/kubelet<<EOF
KUBELET_EXTRA_ARGS="--pod-infra-container-image=registry.hisun.netwarps.com/google_containers/pause:3.2"
EOF

systemctl daemon-reload
systemctl enable --now kubelet # （如果启动失败无需管理，初始化成功以后即可启动）
```

## 操作系统简单初始化

### 关闭swap(阿里云centos7.9 不需要执行)

```
swapoff -a && sysctl -w vm.swappiness=0
sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab
```

### 加载 br_netfilter 模块，设置必要sysctl 参数

```
sudo modprobe br_netfilter

# 设置必需的 sysctl 参数，这些参数在重新启动后仍然存在。
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

### 重启系统

```
reboot
```

## 初始化控制平面节点

### master164-103节点执行初始化

安装命令行补齐工具

```
# 安装bash-completion
yum install bash-completion -y
# 生成kubectl 需要补齐的命令
kubectl completion bash
# 启用所有shell 会话中都引用 kubectl 自动补齐脚本
kubectl completion bash >/etc/bash_completion.d/kubectl
```

```
kubeadm init --image-repository registry.hisun.netwarps.com/google_containers --pod-network-cidr=10.128.0.0/16
```

kubeadm init 首先运行一系列预检查以确保机器 准备运行 Kubernetes。这些预检查会显示警告并在错误时退出。然后 kubeadm init 下载并安装集群控制平面组件。这可能会需要几分钟。 完成之后你应该看到：

```

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.26.164.103:6443 --token 8p7lja.t64yo0w69fnvz6kf \
    --discovery-token-ca-cert-hash sha256:517c42c7e689a50fd04ecb745c34899458ad06fe856d1d718caece81ec56b4e2
```

请运行以下命令,使用用户可以使用kubectl， 它们也是 kubeadm init 输出的一部分：


```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

记录 kubeadm init 输出的 kubeadm join 命令。 你需要此命令将节点加入集群。


### 重置 kubeadm 安装配置（初始化异常中断重装时使用）

```
rm -rf /etc/kubernetes/pki
kubeadm reset 
```

## 添加node节点

在node164-103节点执行

```
kubeadm join 172.26.164.103:6443 --token 8p7lja.t64yo0w69fnvz6kf \
    --discovery-token-ca-cert-hash sha256:517c42c7e689a50fd04ecb745c34899458ad06fe856d1d718caece81ec56b4e2
```

在master164-103节点执行

```
kubectl get nodes
NAME            STATUS     ROLES                  AGE   VERSION
master164-103   NotReady   control-plane,master   36m   v1.20.2
node164-104     NotReady   <none>                 12s   v1.20.2
```

没有安装网络所以node状态是NotReady

## 安装flannel

在master164-103执行

```
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

修改 `kube-flannel.yml` 中 network 与 kubeadm init 配置的  `--pod-network-cidr` 参数值相同

```
  net-conf.json: |
    {
      "Network": "10.128.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
```

执行部署

```
kubectl apply -f kube-flannel.yml
```

查看pod状态

```
kubectl get pod -n kube-system
```

cni网络插件安装完成，查看nodes状态，已经变为Ready

```
kubectl get nodes

NAME            STATUS   ROLES                  AGE   VERSION
master164-103   Ready    control-plane,master   50m   v1.20.2
node164-104     Ready    <none>                 38m   v1.20.2
```

默认master 是不可调度的，需要的话可以删除污点,使master 可以调度

```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## 安装heml

在master164-103主机

```
wget https://get.helm.sh/helm-v3.5.0-linux-amd64.tar.gz
tar xzvf helm-v3.5.0-linux-amd64.tarmv
mv linux-amd64/helm /usr/local/bin/helm
```

## 安装ingress-nginx

### 使用helm安装



```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create namespace ingress

# nginx-ingress 会创建 type 为 LoadBalancer 的 service，可以使用云厂商的负载均衡服务进行对接，这里没有使用， 因此需要配置 EXTERNAL-IP 为k8s集群节点的 IP。 在这里 external-ip 会设置为 [172.26.164.103, 172.26.164.104]

helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress \
--set controller.service.externalIPs[0]=172.26.164.103 \
--set controller.service.externalIPs[1]=172.26.164.104 \
--set controller.image.repository=registry.hisun.netwarps.com/bitnami/nginx-ingress-controller \
--set controller.image.tag=0.43.0 \
--set controller.image.digest=sha256:54f692db893b6f70d8a3650991f112247a3bf905f117ba2e35e977ff313577c5
```

### 检测安装的版本

```
# 查看pod状态
kubectl get pod -n ingress
# 获取pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}' -n ingress)
kubectl exec -it $POD_NAME -- /nginx-ingress-controller --version  -n ingress
# 查看 版本
kubectl -n ingress exec -it $POD_NAME -- /nginx-ingress-controller --version
```

## 安装dashboard

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.1.0/aio/deploy/recommended.yaml
```

### 创建简单用户

创建 service account 

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

创建 ClusterRoleBinding

```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
```

创建 ingress (这里没有使用cert-manager自动管理证书)

```
cat <<EOF > dashboard-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: k8s.hisun.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 8443
EOF

kubectl apply -f dashboard-ingress.yaml
```

获取 Bearer Token

```
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
```

配置解析 ingress-nginx-controller svc 的 EXTERNAL-IP

```
172.16.164.103 k8s.hisun.local
172.16.164.104 k8s.hisun.local
```

访问 `https://k8s.hisun.local`

## 安装 local-path-provisioner

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
## 部署 prometheus-operator

参考： [helm线下部署prometheus-operator](https://github.com/paradeum-team/operator-env/blob/main/prometheus-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2prometheus-operator.md)

## 部署 kafka

### 部署 cert-manager

参考：[线下安装cert-manager](https://github.com/paradeum-team/operator-env/blob/main/cert-manager/%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85cert-manager.md)

### 部署 zookeeper

参考：[helm线下安装zookeeper-operatoor](https://github.com/paradeum-team/operator-env/blob/main/zookeeper-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2zookeeper.md)

### 部署kafka

参考: [helm线下部署kafka-opertor](https://github.com/paradeum-team/operator-env/blob/main/kafka-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2kafka-opertor.md)

## 部署 ECK 日志收集

参考：[helm线下部署ECK日志收集es禁用tls+收集k8s-pods日志](https://github.com/paradeum-team/operator-env/blob/main/elasticsearch/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2ECK%E6%97%A5%E5%BF%97%E6%94%B6%E9%9B%86es%E7%A6%81%E7%94%A8tls%2B%E6%94%B6%E9%9B%86k8s%E6%97%A5%E5%BF%97.md)


## 参考： 
[使用 kubeadm 引导集群](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/)

[安装 kubeadm](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm)

[对 kubeadm 进行故障排查](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)

[kubeadm init](https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-init/)

[高可用安装K8s集群1.20.x](https://www.cnblogs.com/dukuan/p/14124600.html)

[kubernetes-dashboard](https://github.com/kubernetes/dashboard)

[helm部署ingress-nginx](https://kubernetes.github.io/ingress-nginx/deploy/#using-helm)

[https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

[Zookeeper Operator Helm Chart](https://github.com/pravega/zookeeper-operator/tree/master/charts/zookeeper-operator#installing-the-chart)