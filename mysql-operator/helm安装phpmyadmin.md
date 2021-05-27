# helm安装 phpmyadmin

## 下载镜像到私有仓库

```
bitnami/phpmyadmin:5.1.0-debian-10-r74
```

## 添加 helm repo

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## 下载 chart

```
mkdir -p ~/phpmyadmin
cd ~/phpmyqdmin
helm pull bitnami/phpmyadmin
```


## 创建 values.yaml

```
REGISTRY=registry.hisun.netwarps.com
DOMAIN=apps181227.hisun.k8s

cat >values.yaml<<EOF
image:
  registry: $REGISTRY
  repository: bitnami/phpmyadmin
  tag: 5.1.0-debian-10-r74

ingress:
  enabled: true
  hostname: phpmyadmin.$DOMAIN
EOF
```

## 执行安装 phpmyadmin

```
helm upgrade --install phpmyadmin phpmyadmin-8.2.6.tgz -f values.yaml -n mysql-system --set db.host=mysql-cluster-mysql-master.mysql-system
```

注意：`db.host` 如果 在安装时不设置，则需要在访问phpmyadmin 是填写 Mysql 地址，设置了`db.host` ，当前 phpmyadmin 只能访问 `mysql-cluster-mysql-master.mysql-system 数据库
`

## 访问 phpmyadmin

```
http://phpmyadmin.apps181227.hisun.k8s/
```

输入 db 账号密码

## 参考

https://github.com/bitnami/charts/tree/master/bitnami/phpmyadmin

https://artifacthub.io/packages/helm/bitnami/phpmyadmin