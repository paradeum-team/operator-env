# Mac-docker-kubenetes-helm3安装prometheus-operator

## 添加 repo, 更新repo 信息

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

## 查看所有可配置选项的详细注释

```
helm show values prometheus-community/kube-prometheus-stack
```

## 部署prometheus-operator

mac 环境node-exporter因不存在/var/log/pods目录运行失败，所以禁用

```
kubectl create namespace monitoring
helm install prometheus-community prometheus-community/kube-prometheus-stack -n  monitoring \
--set nodeExporter.enabled=false
```

查看 prometheus-operator 相关pod 状态

```
kubectl get pod -n monitoring
```

## 使用port-forward转发grafana服务端口，提供访问入口

```
kubectl port-forward svc/prometheus-community-grafana 3000:80 -n monitoring
```

查看 grafana 登录用户密码

```
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-user:"|awk '{print $2}'|base64 -d
kubectl get secret prometheus-community-grafana -o yaml  -n monitoring |grep " admin-password:"|awk '{print $2}'|base64 -d
```

通过访问 http://127.0.0.1:3000 访问grafana

参考：

https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack