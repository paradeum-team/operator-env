# 1、operator-env

使用operator部署各个应用


## 2、使用helm部署，离线chart包

| 应用名称| chart 名称|  版本| 仓库地址 |BFS下载连接 | helm使用文档|
|:----|:----|:---|:---|:---|:---|
|elasticsearch| eck-operator-1.3.1.tgz | 1.3.1 | [cloud-on-k8s](https://github.com/paradeum-team/cloud-on-k8s) | [链接](https://pnode.solarfs.io/dn/file/2b701b28aa9863eab94b7c5e9705b3a3/eck-operator-1.3.1.tgz) |[doc](https://github.com/paradeum-team/operator-env/blob/main/elasticsearch/elasticsearch-operator.md)|
|skywalking| skywalking-v4.0.0.tgz | v4.0.0 | [skywalking-kubernetes](https://github.com/paradeum-team/skywalking-kubernetes) |[链接](https://pnode.solarfs.io/dn/file/e44e27e67e248662282bbc06f576429f/skywalking-v4.0.0.tgz) |[doc](https://github.com/paradeum-team/operator-env/blob/main/skywalking/skywalking.md) |
|cert-manager| cert-manager-v1.1.0.tgz | v1.1.0 | [cert-manager](https://github.com/paradeum-team/cert-manager) |[链接](https://pnode.solarfs.io/dn/file/82fd2c45957b368fe064fd73f513e96a/cert-manager-v1.1.0.tgz) |[doc](https://github.com/paradeum-team/operator-env/blob/main/cert-manager/%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85cert-manager.md) |
|zookeeper| zookeeper-0.2.9.tgz <br/>zookeeper-operator-0.2.9.tgz | 0.2.9 | [zookeeper-operator](https://github.com/paradeum-team/zookeeper-operator) |[zk-operator](https://pnode.solarfs.io/dn/file/4148c7b4beeac1e8e817f1b54d6d5443/zookeeper-operator-0.2.9.tgz)<br/>[zk](https://pnode.solarfs.io/dn/file/b64335d91bfdb50b13d2146b8903a3fd/zookeeper-0.2.9.tgz) |[doc](https://github.com/paradeum-team/operator-env/blob/main/zookeeper-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2zookeeper.md) |
|kafka| kafka-operator-0.4.4.tgz | 0.4.4 | [kafka-operator](https://github.com/paradeum-team/kafka-operator) | [链接](https://pnode.solarfs.io/dn/file/a941e611cc695a650e9d51e1ecebf591/kafka-operator-0.4.4.tgz) | [doc](https://github.com/paradeum-team/operator-env/blob/main/kafka-operator/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2kafka.md) |
|apollo| apollo-portal-0.1.2.tgz <br/> apollo-service-0.1.2.tgz| 0.1.2 | [apollo](https://github.com/paradeum-team/apollo) |[apollo-portal-0.1.2.tgz](https://pnode.solarfs.io/dn/file/84638082a7d147fc804698420adeef8a/apollo-portal-0.1.2.tgz) <br/> [apollo-service-0.1.2.tgz](https://pnode.solarfs.io/dn/file/d4c62cabd89e622ece7740732091d931/apollo-service-0.1.2.tgz) |[doc](https://github.com/paradeum-team/operator-env/blob/main/apollo/helm%E7%BA%BF%E4%B8%8B%E9%83%A8%E7%BD%B2apollo.md)|
|rabbitmq| rabbitmq-1.4.0.tgz | 1.4.0 | [cluster-operator](https://github.com/rabbitmq/cluster-operator) |[链接](https://pnode.solarfs.io/dn/file/288dbb328faf3fc69a92dd77a95af3d6/rabbitmq-1.4.0.tgz) | [doc](https://github.com/paradeum-team/operator-env/blob/main/rabbitmq-operator/Helm%E5%AE%89%E8%A3%85Rabbitmq-Operator.md) |
|redis| redis-1.0.0.tgz | 1.0.0 | [redis-operator](https://github.com/spotahome/redis-operator) |[链接](https://pnode.solarfs.io/dn/file/1847f6e87e959bee57d12049fe5ef691/redis-1.0.0.tgz) | [doc](https://github.com/paradeum-team/operator-env/blob/main/redis-operator/Helm%E5%AE%89%E8%A3%85Redis-Operator.md) |



