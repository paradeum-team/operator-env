# Centos7安装k8s1.21.0使用阿里云负载均衡部署高可用集群

## 最新的经过验证的 Docker 版本依赖关系

[最新的经过验证的 Docker 版本依赖关系](https://github.com/kubernetes/kubernetes/blob/master/build/dependencies.yaml)

## 主机规划

IP|主机名
-----|-----
172.26.181.227|kont-k8s-master1
172.26.181.228|kont-k8s-master2
172.26.181.229|kont-k8s-master3
172.26.181.230|kont-k8s-node1
172.26.181.231|kont-k8s-node2
172.26.181.232|kont-k8s-node3

信息|备注
-----|-----
系统版本|CentoOS 7.9
Docker 版本|20.10
K8s 版本|1.21
Pod 网段|10.128.0.0/16
Service 网段|10.96.0.0/12

## 搭建负载均衡服务

参考：[软件负载平衡选项指南](https://github.com/kubernetes/kubeadm/blob/master/docs/ha-considerations.md)

### 使用 keepalived+haproxy

略

### 使用阿里云负载均衡

创建阿里云传统型负载均衡 CLB(原 SLB)

IP自动获取为 172.26.181.233
#### 添加监听端口 tcp 6443
设置后端服务器组 
	
```
172.26.181.227:6443
172.26.181.228:6443
172.26.181.229:6443
```

#### 添加监听端口 dnsmasq udp 53

设置后端服务器组 
	
```
172.26.181.227:53
172.26.181.228:53
172.26.181.229:53
```

#### 添加监听端口 chronyd udp 123

设置后端服务器组 
	
```
172.26.181.227:123
172.26.181.228:123
172.26.181.229:123
```
## 所有主机设置主机名

主机配置好对应主机名和解析

```
hostnamectl set-hostname master1.kont.k8s
hostnamectl set-hostname master2.kont.k8s
hostnamectl set-hostname master3.kont.k8s
hostnamectl set-hostname node1.kont.k8s
hostnamectl set-hostname node2.kont.k8s
hostnamectl set-hostname node3.kont.k8s
```

## 所有主机禁用 firewalld

```
systemctl disable firewalld --now
iptables -F
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
  containerd.io-1.4.4 \
  docker-ce-20.10.6 \
  docker-ce-cli-20.10.6
  
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
sudo systemctl enable docker
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

# 安装命令行补全工具 bash-completion
yum install bash-completion -y
# 启用所有shell 会话中都引用 kubectl 自动补齐脚本
kubectl completion bash >/etc/bash_completion.d/kubectl

# 默认配置的pause镜像使用gcr.io仓库，国内可能无法访问，所以这里配置Kubelet使用私有仓库的pause镜像：
cat >/etc/sysconfig/kubelet<<EOF
KUBELET_EXTRA_ARGS="--pod-infra-container-image=registry.hisun.netwarps.com/google_containers/pause:3.2"
EOF

systemctl daemon-reload
systemctl enable --now kubelet # （如果启动失败无需管理，初始化成功以后即可启动）
```

## 操作系统初始化

所有主机执行

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

fs.file-max=655350
fs.inotify.max_queued_events=327679
fs.inotify.max_user_watches=10000000
fs.may_detach_mounts = 1
fs.nr_open=52706963
kernel.msgmax=65536
kernel.msgmnb=65536
kernel.pid_max=65535
kernel.shmall=4294967296
kernel.shmmax=68719476736
kernel.sysrq=1
kernel.unknown_nmi_panic=0
net.core.netdev_max_backlog=50000
net.core.optmem_max=40960
net.core.rmem_default=16777216
net.core.rmem_max=16777216
net.core.somaxconn=4096
net.core.wmem_default=16777216
net.core.wmem_max=16777216
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.ip_local_port_range=32768 60999
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.tcp_abort_on_overflow=1
net.ipv4.tcp_fin_timeout=7
net.ipv4.tcp_keepalive_intvl=3
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_max_orphans=262144
net.ipv4.tcp_max_syn_backlog=30000
net.ipv4.tcp_max_tw_buckets=262144
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_sack=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_syn_retries=2
net.ipv4.tcp_synack_retries=2
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_window_scaling=1
net.ipv6.conf.all.disable_ipv6=1
vm.overcommit_memory=1
vm.panic_on_oom=0
vm.swappiness=0
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

### ipvs 内核配置

#### 所有节点安装ipvsadm

```
yum install ipvsadm ipset sysstat conntrack libseccomp -y
```

#### 加载 ipvs 相关内核配置

```
# load module <module_name>
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4

# to check loaded modules, use
lsmod | grep -e ip_vs -e nf_conntrack_ipv4
# or
cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack_ipv4
```

最后输出检查结果如下

```
nf_conntrack_ipv4
ip_vs_sh
ip_vs_wrr
ip_vs_rr
ip_vs
```

#### 使用 ipvsadm 命令检查

查看端口映射列表

```
ipvsadm -ln
```
### 设置时间同步

#### 安装 chrnoyd

所有主机安装 chonyd

```
yum install -y chronyd
```

所有 master 开放server 同步权限 

```
grep '^allow 0.0.0.0/0' /etc/chrony.conf || echo "allow 0.0.0.0/0" >> /etc/chrony.conf

systemctl restart chronyd
```

所有 node 主机配置 chronyd (master 默认配置不修改)

```
LB_IP=172.26.181.233

cat<<EOF|sudo tee /etc/chrony.conf
server $LB_IP minpoll 4 maxpoll 10 iburst
driftfile /var/lib/chrony/drift
makestep 10 3
rtcsync
local stratum 10
logdir /var/log/chrony
EOF

# 重启 chronyd
systemctl restart chronyd
```

#### 设置时区

```
# 设置时区
timedatectl set-timezone Asia/Shanghai
# 硬件时间设置成 UTC
timedatectl set-local-rtc 0
# 查看时间状态
timedatectl

# 输出下面内容
      Local time: Wed 2021-04-28 17:54:04 CST
  Universal time: Wed 2021-04-28 09:54:04 UTC
        RTC time: Wed 2021-04-28 09:54:04
       Time zone: Asia/Shanghai (CST, +0800)
     NTP enabled: yes
NTP synchronized: yes
 RTC in local TZ: no
      DST active: n/a
```

其中 `NTP synchronized: yes` 表示时间同步正常运行

### 所有节点配置 ulimit

```
cat<<EOF|sudo tee /etc/security/99-limits.conf
* - nofile 65535
* - fsize unlimited
* - nproc 65535 #unlimited nproc for *
EOF
```

### 重启主机 

```
reboot
```

## 配置 dns

### master1-3设置域名解析

```
cat <<EOF | sudo tee -a /etc/hosts
172.26.164.100 registry.hisun.netwarps.com
172.26.181.227 master1.kont.k8s
172.26.181.228 master2.kont.k8s
172.26.181.229 master3.kont.k8s
EOF
```

### 所有 node 设置主机名解析及 api-server解析

例如 node1,依次设置所有 node

```
172.26.181.233	api-server.kont.k8s
172.26.181.230	node1.kont.k8s
```

### 所有主机安装配置 dnsmasq

#### 所有主机安装 dnsmasq

```
yum install -y dnsmasq
```

#### master 主机 dnsmasq 配置
master 主机配置  dnsmasq 默认 上游 dns server 的地址为 阿里云 dns server

```
cat <<EOF | sudo tee /etc/dnsmasq.d/upstream-dns.conf
server=100.100.2.136
server=100.100.2.138
server=/cluster.local/10.96.0.10
EOF
```

默认能用 router 泛解析到 LB

```
cat <<EOF | sudo tee /etc/dnsmasq.d/address-dns.conf
address=/apps181227.hisun.k8s/172.26.181.233
EOF
```

#### node 主机 dnsmasq 配置

```
LB_IP=172.26.181.233
cat <<EOF | sudo tee /etc/dnsmasq.d/upstream-dns.conf
server=$LB_IP
EOF
```

#### 所有主机 配置 kube-dns

```
INTER=eth0
cat <<EOF | sudo tee /etc/dnsmasq.d/kube-dns.conf
no-resolv
domain-needed
no-negcache
max-cache-ttl=1
enable-dbus
dns-forward-max=10000
cache-size=10000
bind-dynamic
min-port=1024
interface=$INTER
except-interface=lo
# End of config
EOF

systemctl restart dnsmasq
```
#### 所有主机配置 /etc/resolv.conf

配置 /etc/resolv.conf, 引用本机 dnsmasq

```
INTER=eth0
LOCAL_IP=`ip addr show eth0|grep inet|awk '{print $2}'|awk -F "/" '{print $1}'`
cat <<EOF | sudo tee /etc/resolv.conf
options timeout:2 attempts:3 rotate single-request-reopen
search kont.k8s cluster.local
nameserver $LOCAL_IP
EOF
```
设置 /etc/resolv.conf 只读

```
chattr +i /etc/resolv.conf
```

设置开机启动 dnsmasq ，并现在启动

```
systemctl enable dnsmasq
systemctl restart dnsmasq
```

## 使用 kubeadm 创建高可用集群

参考：

https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/high-availability/

https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-config/

https://kubernetes.io/zh/docs/reference/setup-tools/kubeadm/kubeadm-init/

https://pkg.go.dev/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm#DNS

https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/control-plane-flags/

https://pkg.go.dev/k8s.io/kubernetes@v1.21.0/cmd/kubeadm/app/apis/kubeadm/v1beta2

https://godoc.org/k8s.io/kubernetes/pkg/proxy/apis/config#KubeProxyConfiguration

### master1节点初始化控制平面

负载均衡用的是阿里云 SLB ，需要注意的是由于阿里云负载均衡不支持后端服务器自己转发给自己，所以 master 节点的 control-plane-endpoint 不能走负载均衡。

创建初始化平面配置

```
MASTER1_IP=172.26.181.227
ETH=eth0
LOCAL_IP=`ip addr show eth0|grep inet|awk '{print $2}'|awk -F "/" '{print $1}'`
HOSTNAME=`hostname`
REGISTRY_REPO=registry.hisun.netwarps.com
MASTER_LB_DNS=api-server.kont.k8s
MASTER_LB_PORT=6443

# 添加MASTER_LB_DNS 解析到master1
grep $MASTER_LB_DNS /etc/hosts &>/dev/null||echo "$MASTER1_IP $MASTER_LB_DNS" >> /etc/hosts

cat >kubeadm-init.yaml<<EOF
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $LOCAL_IP
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: $HOSTNAME
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: $MASTER_LB_DNS:$MASTER_LB_PORT
controllerManager: {}
dns:
  type: CoreDNS
  imageRepository: $REGISTRY_REPO
  imageTag: 1.8.0
etcd:
  local:
    dataDir: /var/lib/etcd
    ExtraArgs:
      listen-metrics-urls=http://0.0.0.0:2381
imageRepository: $REGISTRY_REPO/google_containers
kind: ClusterConfiguration
kubernetesVersion: 1.21.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: "10.128.0.0/16"
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
metricsBindAddress: 0.0.0.0:10249
mode: ipvs
EOF
```

执行控制平面初始化

```
kubeadm init --config ./kubeadm-init.yaml  --upload-certs
```

- 这个 --upload-certs 标志用来将在所有控制平面实例之间的共享证书上传到集群。如果正好相反，你更喜欢手动地通过控制平面节点或者使用自动化 工具复制证书，请删除此标志并参考[证书分配手册](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/high-availability/#manual-certs)。

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

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join api-server.kont.k8s:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:9c66b3606d462c1f65e1e3214ebdb7c33797a9326b3cb53fd676be00737e9248 \
	--control-plane --certificate-key 0b37558dc8f7ae79703754816b0ab65641e0f90050ad4ffc59d8fcca5e6314df

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join api-server.kont.k8s:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:9c66b3606d462c1f65e1e3214ebdb7c33797a9326b3cb53fd676be00737e9248
```

请运行以下命令,使用用户可以使用kubectl， 它们也是 kubeadm init 输出的一部分：

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

记录 kubeadm init 输出的 kubeadm join 命令。 你需要此命令将节点加入集群。


### 配置 coredns forward

coredns forward 指向到 dns lb 

```
DNS_SERVER=172.26.181.233:53
cat > coredns-config.yaml <<EOF
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . $DNS_SERVER {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
EOF

kubectl apply -f coredns-config.yaml -n kube-system
kubectl rollout restart deploy coredns -n kube-system
```

### 重置 kubeadm 安装配置（初始化异常中断重装时使用）

```
kubeadm reset 
rm -rf /etc/kubernetes/pki
rm -f $HOME/.kube/config
```

### 其余控制平面节点的步骤

在 master2-3 执行

添加 MASTER_LB_DNS 解析到本机

```
# 指定网卡
MASTER1_IP=172.26.181.227
ETH=eth0
LOCAL_IP=`ip addr show eth0|grep inet|awk '{print $2}'|awk -F "/" '{print $1}'`
HOSTNAME=`hostname`
MASTER_LB_DNS=api-server.kont.k8s
MASTER_LB_PORT=6443

# 添加MASTER_LB_DNS 解析到master1
grep $MASTER_LB_DNS /etc/hosts &>/dev/null||echo "$MASTER1_IP $MASTER_LB_DNS" >> /etc/hosts
```

执行先前由第一个节点上的 kubeadm init 输出提供给您的 join 控制平面命令。 它看起来应该像这样：

```
kubeadm join api-server.kont.k8s:6443 --token abcdef.0123456789abcdef \
--discovery-token-ca-cert-hash sha256:9c66b3606d462c1f65e1e3214ebdb7c33797a9326b3cb53fd676be00737e9248 \
--control-plane --certificate-key 0b37558dc8f7ae79703754816b0ab65641e0f90050ad4ffc59d8fcca5e6314df
```

api server dns 改为本机 IP

```
sed -i "s/.*api-server.kont.k8s/$LOCAL_IP api-server.kont.k8s/g" /etc/hosts
systemctl restart dnsmasq
```

### 其余 node 节点添加步骤

执行先前由第一个节点上的 kubeadm init 输出提供给您的 join node 节点命令。 它看起来应该像这样：

```
kubeadm join api-server.kont.k8s:6443 --token abcdef.0123456789abcdef \
--discovery-token-ca-cert-hash sha256:9c66b3606d462c1f65e1e3214ebdb7c33797a9326b3cb53fd676be00737e9248
```
## 安装 flannel

在 master1 执行

```
wget https://raw.githubusercontent.com/coreos/flannel/v0.13.0/Documentation/kube-flannel.yml
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

修改 image registry repo

```
sed -i 's/quay.io/registry.hisun.netwarps.com/g' kube-flannel.yml
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
NAME               STATUS   ROLES                  AGE     VERSION
master1.kont.k8s   Ready    control-plane,master   3h58m   v1.21.0
master2.kont.k8s   Ready    control-plane,master   3h56m   v1.21.0
master3.kont.k8s   Ready    control-plane,master   3h52m   v1.21.0
node1.kont.k8s     Ready    <none>                 3h32m   v1.21.0
node2.kont.k8s     Ready    <none>                 15m     v1.21.0
node3.kont.k8s     Ready    <none>                 15m     v1.21.0
```
默认master 是不可调度的，需要的话可以删除污点,使master 可以调度(生产环境不建议)

```
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## 安装heml

在master1主机

```
wget https://get.helm.sh/helm-v3.5.4-linux-amd64.tar.gz
tar xzvf helm-v3.5.4-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
```

## 安装ingress-nginx

### 使用helm安装

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create namespace ingress

# nginx-ingress 会创建 type 为 LoadBalancer 的 service，可以使用云厂商的负载均衡服务进行对接
# 阿里云环境使用 ipvs ,不能添加 controller.service.externalIPs, 否则会导致 externalIPs 的所在节点 访问 externalIPs 所在网段访问不通
# nginx-ingress 部署到 master 节点不抢占 node 资源


helm pull ingress-nginx/ingress-nginx

# 创建 values.yaml

REGISTRY=registry.hisun.netwarps.com

cat > values.yaml <<EOF
controller:
  image:
    repository: ${REGISTRY}/bitnami/nginx-ingress-controller
    tag: 0.44.0
    digest: sha256:278ad67a8f9f2008d213c86c43c3f37f69ccdecfded91bf57aaab3e4cd6ebc58
  admissionWebhooks:
    patch:
      image:
        repository:  ${REGISTRY}/jettech/kube-webhook-certgen
  kind: DaemonSet
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
EOF

# 更新或创建 ingress
helm upgrade ingress-nginx ingress-nginx-3.29.0.tgz -f values.yaml -n ingress
```


### 阿里云负载均衡反向代理 ingress-nginx

查看 ingress-ingix svc

```
kubectl get svc -n ingress

NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.109.127.169   <pending>     80:30812/TCP,443:30482/TCP   16h
ingress-nginx-controller-admission   ClusterIP      10.99.172.75     <none>        443/TCP                      16h
```

阿里云负载均衡添加监听tcp 80

设置后端地址列表

```
172.26.181.227:30812
172.26.181.228:30812
172.26.181.229:30812
```

阿里云负载均衡添加监听tcp 443

设置后端地址列表

```
172.26.181.227:30482
172.26.181.228:30482
172.26.181.229:30482
```

设置后，就可以使用负载均衡 IP 访问 ingress 了

```
http://172.26.181.233
https://172.26.181.233
```

### 检测安装的版本

```
# 查看pod状态
kubectl get pod -n ingress
# 获取pod name
POD_NAME=$(kubectl get pods --field-selector=status.phase=Running -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}' -n ingress)
kubectl exec -it $POD_NAME -- /nginx-ingress-controller --version  -n ingress
# 查看 版本
kubectl -n ingress exec -it $POD_NAME -- /nginx-ingress-controller --version
```

## 安装dashboard

参考：[k8s-1.21安装dashboard](./k8s-1.21安装dashboard.md)

## 安装 rancher

参考：[helm线下安装rancher](../rancher/helm线下安装rancher.md)

## 安装 local-path-provisioner(local path storage class)

适用场景：

- 磁盘性能要求中高
- 允许其它服务抢占io资源
- 不限制挂载磁盘空间大小
- pod 固定节点
- 单 pod 读写


参考: [安装local-path-provisioner.md](../storage/安装local-path-provisioner.md)

## 安装 nfs-subdir-external-provisioner(nfs storage class)

适用场景：

- 磁盘性能要求中低
- 允许其它服务抢占io资源
- 不限制挂载磁盘空间大小
- pod 不固定节点
- 多 pod 同时读写


**注意：发布的服务磁盘性能需求低，且不固定节点，使用  nfs3-client **

参考: [k8s1.20使用helm部署nfs-subdir-external-provisioner对接阿里云NAS-NFS](../storage/k8s1.20使用helm部署nfs-subdir-external-provisioner对接阿里云NAS-NFS.md)

## 安装 sig-storage-local-static-provisioner(local volume storage class)

适用场景：

- 磁盘性能要求高
- 不允许其它服务抢占io资源
- 限制挂载磁盘空间大小
- pod 固定节点
- 单 pod 读写

参考: [k8s-1.21配置local-volume](../storage/k8s-1.21配置local-volume.md)

## 部署 prometheus-operator

**安装注意：因磁盘性能要求不同，需要修改 storageclass**

- alertmanager 使用 nfs3-client
- grafana 使用 nfs3-client
- prometheus 使用 local-volume

参考： [helm线下部署prometheus-operator](../prometheus-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2prometheus-operator.md)

## 部署 kafka

### 部署 cert-manager

参考：[线下安装cert-manager](../cert-manager/%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85cert-manager.md)

### 部署 zookeeper

**安装注意：因磁盘性能要求不同，需要修改 storageclass**

- zookeeper 使用 local-path

参考：[helm线下安装zookeeper-operator](../zookeeper-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2zookeeper.md)

### 部署kafka

**安装注意：因磁盘性能要求不同，需要修改 kafka storageclass**

- kafka 使用 local-volume

参考: [helm线下部署kafka-opertor](../kafka-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2kafka-opertor.md)

## 部署 ECK 日志收集

**安装注意：因磁盘性能要求不同，需要修改 storageclass**

- elasticsearch 使用 local-volume

参考：[helm线下部署ECK日志收集es禁用tls+收集k8s-pods日志](../elasticsearch/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2ECK%E6%97%A5%E5%BF%97%E6%94%B6%E9%9B%86es%E7%A6%81%E7%94%A8tls%2B%E6%94%B6%E9%9B%86k8s%E6%97%A5%E5%BF%97.md)

## 参考
[CentOS7.9-安装k8s-1.20.2](https://github.com/paradeum-team/operator-env/blob/main/centos7-k8s/CentOS7.9-%E5%AE%89%E8%A3%85k8s-1.20.0.md)

[利用 kubeadm 创建高可用集群](https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/high-availability/)

[高可用安装K8s集群1.20.x](https://www.cnblogs.com/dukuan/p/14124600.html)

[搭建 Kubernetes 高可用集群](https://www.cnblogs.com/dudu/p/12168433.html)

[访问 externalTrafficPolicy 为 Local 的 Service 对应 LB 有时超时](https://k8s.imroc.io/avoid/cases/lb-with-local-externaltrafficpolicy-timeout-occasionally/)

[kubectl 备忘单](https://kubernetes.io/zh/docs/reference/kubectl/cheatsheet/)

[coredns loop troubleshooting](https://coredns.io/plugins/loop/#troubleshooting)

[自定义 DNS 服务](https://kubernetes.io/zh/docs/tasks/administer-cluster/dns-custom-nameservers/)

[coredns forward](https://coredns.io/plugins/forward/)