# Centos7-k8s-1.20.2使用kubeadm添加node

## master主机添加新node域名解析

```
cat <<EOF | sudo tee -a /etc/hosts
172.26.164.105 node164-105 node164-105
172.26.164.106 node164-106 node164-106
172.26.164.107 node164-107 node164-107
EOF
```

## 新node设置主机名

```
hostnamectl set-hostname node164-105
hostnamectl set-hostname node164-106
hostnamectl set-hostname node164-107
```

## 新node禁用firewalld

```
systemctl disable firewalld --now
iptables -t nat -F && iptables -t mangle -F
```

## 新node安装容器运行时

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


## 新nodoe节点安装 kubeadm、kubelet 和 kubectl

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


## 新node节点操作系统简单初始化

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

## master主机生成添加 token

创建添加token,默认24小时有效

```
kubeadm token create --print-join-command

# 下面为结果显示内容，不在master节点执行，在新nodo节点执行添加
kubeadm join 172.26.164.103:6443 --token 9v80nd.okf7rkp96lwjqmn5     --discovery-token-ca-cert-hash sha256:517c42c7e689a50fd04ecb745c34899458ad06fe856d1d718caece81ec56b4e2
```

查看token 列表

```
kubeadm token list

TOKEN                     TTL         EXPIRES                     USAGES                   DESCRIPTION                                                EXTRA GROUPS
9v80nd.okf7rkp96lwjqmn5   23h         2021-01-26T17:26:14+08:00   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token
```

## 新node节点执行添加

```
kubeadm join 172.26.164.103:6443 --token 9v80nd.okf7rkp96lwjqmn5     --discovery-token-ca-cert-hash sha256:517c42c7e689a50fd04ecb745c34899458ad06fe856d1d718caece81ec56b4e2
```

## master获取节点列表

获取节点列表，刚添加完成时，有可能是 `NotReady` 状态, 需要等几分钟，全部`Ready` 状态后就可以使用了

```
kubectl get nodes

NAME            STATUS     ROLES                  AGE     VERSION
master164-103   Ready      control-plane,master   6d2h    v1.20.2
node164-104     Ready      logging                6d2h    v1.20.2
node164-105     NotReady   <none>                 2m18s   v1.20.2
node164-106     NotReady   <none>                 2m15s   v1.20.2
node164-107     Ready      <none>                 2m13s   v1.20.2
```