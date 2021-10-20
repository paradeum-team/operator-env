# 使用filebeat收集k8s集群pod日志


## 下载yaml

```
https://raw.githubusercontent.com/elastic/beats/7.15/deploy/kubernetes/filebeat-kubernetes.yaml
```

修改下面相关配置

- 增加 tolerations
- 修改 image 
- 修改 env

```
...
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      tolerations:
        - effect: NoSchedule
          operator: Exists
...
        image: registry.hisun.netwarps.com/beats/filebeat:7.15.1
...

        env:
        - name: ELASTICSEARCH_HOST
          value: bfs-es-master.elastic-system.svc
        - name: ELASTICSEARCH_PASSWORD
          value: xxxxxxxxx
...
```

## 部署

```
kubectl apply -f filebeat-kubernetes.yaml
```

## 使用 kibana 创建索引

创建 filebeat-7.15.1 索引 

## 参考

https://www.elastic.co/guide/en/beats/filebeat/7.15/running-on-kubernetes.html