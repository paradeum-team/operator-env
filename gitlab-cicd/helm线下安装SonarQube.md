# helm线下安装SonarQube



## 添加 sonarqube chart repo, 下载 chart 包

```
helm repo add oteemocharts https://oteemo.github.io/charts
helm pull oteemocharts/sonarqube
```

## 参考 chart 变量

```
https://github.com/Oteemo/charts/blob/master/charts/sonarqube/values.yaml
```

## 安装

```
helm install sonarqube sonarqube-9.5.0.tgz \
 -n sonarqube --create-namespace \
 --set image.repository=registry.hisun.netwarps.com/library/sonarqube \
 --set initContainers.image=registry.hisun.netwarps.com/library/busybox:1.32 \
 --set initSysctl.image=registry.hisun.netwarps.com/library/busybox:1.32 \
 --set tests.image=registry.hisun.netwarps.com/dduportal/bats:0.4.0 \
 --set ingress.enabled=true \
 --set ingress.hosts[0].name=sonar.apps164103.hisun.local \
 --set postgresql.image.registry=registry.hisun.netwarps.com \
 --set postgresql.image.tag=11.9.0
```

```
helm upgrade sonarqube sonarqube-9.5.0.tgz \
 -n sonarqube --create-namespace \
 --set image.repository=registry.hisun.netwarps.com/library/sonarqube \
 --set initContainers.image=registry.hisun.netwarps.com/library/busybox:1.32 \
 --set initSysctl.image=registry.hisun.netwarps.com/library/busybox:1.32 \
 --set tests.image=registry.hisun.netwarps.com/dduportal/bats:0.4.0 \
 --set ingress.enabled=true \
 --set ingress.hosts[0].name=sonar.apps164103.hisun.local \
 --set postgresql.image.registry=registry.hisun.netwarps.com \
 --set postgresql.image.tag=11.9.0
```

## 访问

解析 sonar.apps164103.hisun.local 域名到 ingress 主机

访问下面地址

```
http://sonar.apps164103.hisun.local/
```

默认账号密码 admin admin 

## 参考 

[https://github.com/Oteemo/charts/tree/master/charts/sonarqube](https://github.com/Oteemo/charts/tree/master/charts/sonarqube)
