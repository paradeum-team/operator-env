# helm 安装 redmine

## 添加 helm chart repo

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## 下载 chart
```
mkdir ~/redmine
cd ~/redmine/
helm pull bitnami/redmine
```

## 在已有 mysql 中创建 redmine 数据库并授权

登录现有 mysql-operator 部署的 mysql

```
mysql -uroot -hmysql-cluster-mysql-master.mysql-system.svc -p
```

```
CREATE DATABASE `bitnami_redmine` /*!40100 DEFAULT CHARACTER SET utf8mb4 */;
GRANT ALL PRIVILEGES ON `bitnami_redmine `.* TO `bn_redmine`@`%` IDENTIFIED BY "123456";
flush privileges;
```

注意：生产数据库 密码123456 改为复杂密码

## 创建 values.yaml

```
REGISTRY=registry.hisun.netwarps.com
DOMAIN=apps181227.hisun.k8s
PASSWORD=123456

cat > values.yaml <<EOF
image:
  registry: docker.io
  repository: bitnami/redmine
  tag: 4.2.1-debian-10-r26
  
ingress:
  enabled: true
  hostname: redmine.$DOMAIN
  
databaseType: mariadb

mariadb:
  enabled: false

externalDatabase:
  host: "mysql-cluster-mysql-master.mysql-system.svc"
  name: bitnami_redmine
  password: "$PASSWORD"
EOF
```

## 执行安装 redmine

```
helm upgrade --install redmine redmine-15.2.18.tgz -f values.yaml -n redmine --create-namespace
```

查看使用的 mysql 密码

```
kubectl get secret --namespace "redmine" redmine-externaldb -o jsonpath="{.data.mariadb-password}" | base64 --decode;echo
```

## 访问 redmine

```
http://redmine.apps181227.hisun.k8s/
```

默认管理员账号 user

查看默认管理员密码

```
kubectl get secret --namespace "redmine" redmine -o jsonpath="{.data.redmine-password}" | base64 --decode;echo
```

## 参考：

https://artifacthub.io/packages/helm/bitnami/redmine

https://github.com/bitnami/charts/tree/master/bitnami/redmine