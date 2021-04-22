# 线下安装 kube-bench 扫描kubenetes1.20

## 下载镜像到私有仓库

```
aquasec/kube-bench:0.5.0
```

## 下载 job.yaml

```
https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

修改 job.yaml 中 镜像地址

```
      containers:
        - name: kube-bench
          image: registry.hisun.netwarps.com/aquasec/kube-bench:0.5.0
```

## 执行 kube-bench job 扫描

```
$ kubectl apply -f job.yaml
job.batch/kube-bench created

$ kubectl get pods
NAME                      READY   STATUS              RESTARTS   AGE
kube-bench-j76s9   0/1     ContainerCreating   0          3s

# 等待 job pod 状态变成 complete 状态
$ kubectl get pods
NAME                      READY   STATUS      RESTARTS   AGE
kube-bench-j76s9   0/1     Completed   0          11s

# 查看扫描结果日志
kubectl logs kube-bench-j76s9
[INFO] 1 Master Node Security Configuration
[INFO] 1.1 API Server
...
```

## 参考

https://github.com/aquasecurity/kube-bench#running-in-a-kubernetes-cluster