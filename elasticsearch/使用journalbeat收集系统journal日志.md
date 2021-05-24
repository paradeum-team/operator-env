# 使用journalbeat收集系统journal日志

## 安装收集操作系统日志的 journalbeat

下载下面两个 yaml ，修改其中的 image 为私有仓库，修改 kafka 相关地址

[system-journalbeat.yaml](./yamls/system-journalbeat.yaml)

[system-logstash.yaml](./yamls/system-logstash.yaml)

部署 journalbeat

```
kubectl apply -f system-journalbeat.yaml
``` 

部署 logstash

```
kubectl apply -f system-logstash.yaml
``` 

## kibana 创建索引

### 登录 kibana
kibana 默认登录账号为 elastic, 查看密码

```
kubectl get secret kont-es-elastic-user -o=jsonpath='{.data.elastic}' -n elastic-system| base64 --decode; echo
```

访问 kibana 管理页面

```
https://kont-kibana.apps181227.hisun.k8s/
```

### 创建 journalbeat 索引

左边总菜单-->  最下方 Stack Management --> Index Patterns --> Create index pattern

`Index pattern name` 输入 journalbeat-system

`Time field` 选择 @timestamp

点击 `Create index pattern`

### 创建索引模板

左边总菜单--> `Index Management` --> Index Templates --> Create Template 


`Name` 输入 `journalbeat`

`Index patterns` 输入 `journalbeat-*`

`Data stream` 开启 `Create data stream`

点击 `Next`


选择 logs-mappings、logs-settings

点击 `Next`

其它都是直接点 `Next`

直到最后 Review details for 'journalbeat'

点击 `Create Template`

### 绑定索引生命周期策略

左边总菜单--> Stack Management --> Index Lifecycle Policies

选中 `logs` 对应的 `Actions` --> Add policy to index template --> Add policy "logs" to index template

Index template 选择 `journalbeat`

点击 `Add Policy`


### 查询应用日志

左上角总菜单 --> Analyties --> Discover

选择 journalbeat-system 索引 查询

## 参考: 

[https://www.elastic.co/guide/en/beats/journalbeat/current/running-on-docker.html](https://www.elastic.co/guide/en/beats/journalbeat/current/running-on-docker.html)