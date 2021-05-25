# 使用 pptpd 打通 windows 开发机与 k8s 网络

## 在 k8s 任意节点安装 pptpd 

我是选择在 `172.26.181.227` 上安装 pptpd

### 安装 `docker-compose`

```
yum install docker-compose
```

### 目录结构

```
~/pptpd/
├── docker-compose.yml
└── data/
    ├── pptpd.conf
    ├── pptpd-options
    └── chap-secrets
```

创建目录

```
mkdir -p ~/pptpd/data
cd ~/pptpd
```

创建 docker-compose.yml

```
cat > docker-compose.yml<<EOF
pptpd:
  image: vimagick/pptpd
  volumes:
    - ./data/pptpd.conf:/etc/pptpd.conf
    - ./data/pptpd-options:/etc/ppp/pptpd-options
    - ./data/chap-secrets:/etc/ppp/chap-secrets
  privileged: true
  restart: always
EOF
```

创建 pptpd.conf 

注意：

- localip vpn server ip
- remoteip 远程连接的 vpn 客户端分配的 ip
- 不能和当前本地网段、k8s 服务和容器网络冲突

```
cat > data/pptpd.conf<<EOF
option /etc/ppp/pptpd-options
pidfile /var/run/pptpd.pid
localip 192.168.0.1
remoteip 192.168.0.100-199
EOF
```

创建 pptpd-options

```
DNS_SERVER=172.26.181.233

cat > data/pptpd-options<<EOF
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
proxyarp
nodefaultroute
lock
nobsdcomp
novj
novjccomp
nologfd
ms-dns $DNS_SERVER
EOF
```

创建 chap-secrets

注意：请在chap-secrets文件中使用强密码来保护您的服务器。

```
cat > data/chap-secrets<<EOF
# Secrets for authentication using CHAP
# client    server  secret          IP addresses
win235    *       123456        192.168.0.100
EOF
```

### 服务器设置并启动

- 在启动之前请确保客户端 IP 可以访问 pptpd 服务器 1723/tcp 端口
- 设置 net.ipv4.ip_forward=1 (sysctl, k8s 环境都会开启，所以在 k8s 节点不需要设置)

```
modprobe nf_conntrack_pptp
modprobe nf_nat_pptp
cd ~/pptpd
docker-compose up -d 		# 启动
netstat -lntp|grep 1723 	# 查看监听端口是否存在
docker-compose logs -f 		# 查看日志
```

## windows 客户端连接 pptpd

### 添加 VPN

开始菜单--> 设置 --> 网络和 Internet --> VPN --> 添加 VPN 连接

`VPN 提供商` 选择 `Windows(内置)`

`连接名称` 填写 `k8s227-vpn`

`服务器名称或地址` 填写 `172.26.181.227`

`VPN 类型` 选择 `点对点隧道协议 PPTP`

`登录信息的类型` 选择 `用户名和密码`

`用户名` 填写 `win235`

`密码` 填写 `123456`

点击 `保存`

### 修改 vpn 不启用默认网关

开始菜单--> 设置 --> 网络和 Internet --> 更改适配器选项 -->

选择 `k8s227-vpn` 右键 `属性` --> 网络 --> 选择 Internet 协议版本4(TCP/IPv4) --> 属性 --> 高级 --> IP设置 --> 去掉 `在远程网络上使用默认网关` 复选框的对勾 --> 确定 --> 确定 --> 确定

### 连接 k8s vpn

点击 windows 桌面右下角 `网络` 图标 --> 选择 k8s227-vpn --> 连接

### 根据 k8s service 和 pod 网段添加 windows 永久静态路由

在 windows 开发机 打开 `windows powerShell` 或 `cmd` 命令行


查看网卡列表

```
ipconfig
```

可以看到 ppp适配器的 vpn ip 192.168.0.100

```
Windows IP 配置

以太网适配器 以太网:

...

PPP 适配器 k8s227-vpn:

   连接特定的 DNS 后缀 . . . . . . . :
   IPv4 地址 . . . . . . . . . . . . : 192.168.0.100
   子网掩码  . . . . . . . . . . . . : 255.255.255.255
   默认网关. . . . . . . . . . . . . :
```

在 k8s master 主机查看 已经安装的 k8s service 和 pod 网段

```
kubectl get cm kubeadm-config -n kube-system -o yaml|grep Subnet

# 显示如下
      podSubnet: 10.128.0.0/16
      serviceSubnet: 10.96.0.0/12
```

根据 k8s service 和 pod 网段，修改下面命令中 ip 段 及 MASK 并执行

```
route ADD -p 10.96.0.0 MASK 255.240.0.0 192.168.0.100
route ADD -p 10.128.0.0 MASK 255.255.0.0 192.168.0.100
```

查看 router 信息

```
route print
```

可以看到永久路由配置如下

```
...
永久路由:
  网络地址          网络掩码  网关地址  跃点数
     172.26.181.0    255.255.255.0   172.26.181.230       1
       10.128.0.0      255.255.0.0    192.168.0.100       1
        10.96.0.0      255.240.0.0    192.168.0.100       1
```

测试 ping k8s 中 pod ip

```
ping 10.96.0.1

# 显示已经可以 ping 通
正在 Ping 10.96.0.1 具有 32 字节的数据:
来自 10.96.0.1 的回复: 字节=32 时间<1ms TTL=64
来自 10.96.0.1 的回复: 字节=32 时间<1ms TTL=64
```

## 参考：

https://hub.docker.com/r/vimagick/pptpd

https://zhuanlan.zhihu.com/p/187548589

https://blog.csdn.net/sltin/article/details/100044930

http://www.itersblog.com/archives/61.html