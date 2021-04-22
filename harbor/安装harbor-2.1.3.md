# 安装harbor-2.1.3

## 安装docker

```
yum install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum install docker -y
systemctl enable docker --now
```

## 安装docker-compose

```
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

## 安装harbor

```
mkdir -p /data
```

下载harbor 线下安装包

```
cd /data
wget https://github.com/goharbor/harbor/releases/download/v2.1.3/harbor-offline-installer-v2.1.3.tgz
tar xvf harbor-offline-installer-v2.1.3.tgz

cd /data/harbor
mkdir -p cert

```

上传证书到cert目录

复制配置模板文件为最终配置

```
cp harbor.yml.temp harbor.yml
```

修改 harbor.yml 中 

```
hostname
https:
  # https port for harbor, default is 443
  port: 443
  # The path of cert and key files for nginx
  certificate: /data/harbor/cert/registry.hisun.netwarps.com.pem
  private_key: /data/harbor/cert/registry.hisun.netwarps.com.key

```

执行安装

```
./install.sh
```

## 异常处理

## docker 重启后，harbor 相关容器部分不能正常启动

查看异常容器

```
docker ps -a
```

手动启动异常容器

```
docker start NAME
```