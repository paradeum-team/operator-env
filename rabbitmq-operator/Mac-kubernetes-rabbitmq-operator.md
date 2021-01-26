# Rabbitmq-operator yaml方式部署

### 环境准备

- Kubernetes 1.17或以上
- RabbitMQ image 3.8.8+

### 部署 rabbitmq cluster-operator
- 下载部署文件[cluster-operator.yml](https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml)
- 执行 

		kubectl apply -f cluster-operator.yml

### 部署 rabbitmq 服务
- 下载部署文件 [rabbitmq.yaml](https://raw.githubusercontent.com/rabbitmq/cluster-operator/main/docs/examples/hello-world/rabbitmq.yaml)
- 执行
	
	kubectl apply -f rabbitmq.yaml

### 如果遇到找不到pvc的问题可能是本地没有指定storageClass

```
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: hello-world
spec:
   persistence:
    storageClassName: local-path
    storage: 10Gi
	
```
### 验证服务可用性

- 查看crd是否创建成功

    ```
    kubectl get customresourcedefinitions.apiextensions.k8s.io

    # NAME                                   CREATED AT
    # rabbitmqclusters.rabbitmq.com               2021-01-14T09:15:45Z
    ```
- 查看相关服务是否正常运行，svc、pod和statefulset

    ```
    kubectl get all -l app.kubernetes.io/name=hello-world

    NAME                       READY   STATUS    RESTARTS   AGE
    pod/hello-world-server-0   1/1     Running   0          4d17h

    NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                        AGE
    service/hello-world         ClusterIP   10.110.240.49   <none>        15672/TCP,5672/TCP             4d17h
    service/hello-world-nodes   ClusterIP   None            <none>        4369/TCP,25672/TCP             4d17h
    service/rabbitmq            ClusterIP   None            <none>        5672/TCP,15692/TCP,15672/TCP   16h

    NAME                                  READY   AGE
    statefulset.apps/hello-world-server   1/1     4d17h
    ```

- 访问 Rabbitmq UI 控制界面

    ```
    # 端口转发
    kubectl port-forward svc/rabbitmq 15672:15672 -n default

    # 访问 
    http://localhost:15672
    ```

- 访问metric
- metric默认端口为15692，需要更改service，将端口暴露出来。我重新创建了一个svc，名字叫rabbitmq

    ```
    # 端口转发
    kubectl port-forward svc/rabbitmq 15692:15692 -n default
    
    # 访问地址
    http://localhost:15692/metrics
    ```

- 获取用户密码

    ```
    # 默认用户
    kubectl -n default get secret hello-world-default-user -o jsonpath="{.data.username}" | base64 --decode

    # 默认密码
    kubectl -n default get secret hello-world-default-user -o jsonpath="{.data.password}" | base64 --decode
    ```
   
- 创建用户密码（自定义）

    ```
    # 进入容器内执行，添加admin用户，密码为admin
    rabbitmqctl  add_user admin admin

    # 将admin加入到管理员组
    rabbitmqctl set_user_tags admin administrator
    
    #查看用户列表
    rabbitmqctl  list_users
    ```
    
- 测试rabbitmq，使用吞吐量测试工具PerfTest
  - 要安装并运行 PerfTest，请运行以下命令:
  
    ```
    kubectl run perf-test --image=pivotalrabbitmq/perf-test -- --uri "amqp://${username}:${password}@${service}"
    ```
    
    即：
    
    ```
    # 使用默认初始化的用户名密码，在Secrets中找到hello-world-default-user获取密码
    kubectl run perf-test --image=pivotalrabbitmq/perf-test -- --uri "amqp://JxMMlmr-925Ip3rviMLvMur7PgqMPIqN:LHlv-0_sQ7upKL-AHbHzFiRCI4l-2UWe@hello-world"
    
    ```
  - 要验证 PerfTest 正在发送和接收消息，请运行:
  
    ```
    kubectl logs -f perf-test
    
    --- log
    id: test-070938-160, starting consumer #0
    id: test-070938-160, starting consumer #0, channel #0
    id: test-070938-160, starting producer #0
    id: test-070938-160, starting producer #0, channel #0
    id: test-070938-160, time: 1.000s, sent: 5189 msg/s, received: 4879 msg/s, min/median/75th/95th/99th consumer latency: 656/18243/29917/34666/36136 µs
    id: test-070938-160, time: 2.000s, sent: 10372 msg/s, received: 10468 msg/s, min/median/75th/95th/99th consumer latency: 588/27038/35706/63525/70820 µs
    id: test-070938-160, time: 3.000s, sent: 13812 msg/s, received: 13712 msg/s, min/median/75th/95th/99th consumer latency: 3247/20231/22328/29318/31706 µs
    id: test-070938-160, time: 4.000s, sent: 10989 msg/s, received: 9836 msg/s, min/median/75th/95th/99th consumer latency: 1108/24312/28590/237348/243192 µs
    id: test-070938-160, time: 5.000s, sent: 9792 msg/s, received: 9372 msg/s, min/median/75th/95th/99th consumer latency: 145219/193965/206720/248354/255877 µs
    id: test-070938-160, time: 6.000s, sent: 14046 msg/s, received: 14740 msg/s, min/median/75th/95th/99th consumer latency: 77437/97435/112879/156730/163772 µs
    id: test-070938-160, time: 7.000s, sent: 13884 msg/s, received: 14377 msg/s, min/median/75th/95th/99th consumer latency: 41335/73477/81641/106649/111453 µs
    id: test-070938-160, time: 8.000s, sent: 14764 msg/s, received: 15245 msg/s, min/median/75th/95th/99th consumer latency: 12062/17996/20240/33085/52892 µs
    id: test-070938-160, time: 9.000s, sent: 13835 msg/s, received: 13943 msg/s, min/median/75th/95th/99th consumer latency: 917/11065/21740/25499/25977 µs
    id: test-070938-160, time: 10.000s, sent: 14920 msg/s, received: 14538 msg/s, min/median/75th/95th/99th consumer latency: 1858/11646/18300/28810/30998 µs
    id: test-070938-160, time: 11.000s, sent: 13703 msg/s, received: 11387 msg/s, min/median/75th/95th/99th consumer latency: 36524/117669/173594/189302/191222 µs
    id: test-070938-160, time: 12.000s, sent: 13723 msg/s, received: 13441 msg/s, min/median/75th/95th/99th consumer latency: 197353/232015/240885/247814/252437 µs
    id: test-070938-160, time: 13.000s, sent: 13643 msg/s, received: 14026 msg/s, min/median/75th/95th/99th consumer latency: 167891/209603/229313/261225/263025 µs
    id: test-070938-160, time: 14.000s, sent: 13993 msg/s, received: 15016 msg/s, min/median/75th/95th/99th consumer latency: 114820/136610/168352/196385/200186 µs
    id: test-070938-160, time: 15.000s, sent: 14654 msg/s, received: 14963 msg/s, min/median/75th/95th/99th consumer latency: 86666/105485/117187/136178/138080 µs
    id: test-070938-160, time: 16.000s, sent: 11342 msg/s, received: 12306 msg/s, min/median/75th/95th/99th consumer latency: 5686/72622/82426/100390/102011 µs
    id: test-070938-160, time: 17.000s, sent: 12951 msg/s, received: 13249 msg/s, min/median/75th/95th/99th consumer latency: 828/3965/5199/12297/51241 µs
    id: test-070938-160, time: 18.000s, sent: 13300 msg/s, received: 13112 msg/s, min/median/75th/95th/99th consumer latency: 20290/27959/30696/35231/41854 µs
    id: test-070938-160, time: 19.000s, sent: 13170 msg/s, received: 12976 msg/s, min/median/75th/95th/99th consumer latency: 17464/26272/34700/41748/47842 µs
    id: test-070938-160, time: 20.000s, sent: 14139 msg/s, received: 14501 msg/s, min/median/75th/95th/99th consumer latency: 10051/27651/31509/38454/41857 µs
    id: test-070938-160, time: 21.000s, sent: 11956 msg/s, received: 11647 msg/s, min/median/75th/95th/99th consumer latency: 4883/32439/41343/46054/48173 µs
    id: test-070938-160, time: 22.000s, sent: 12726 msg/s, received: 12736 msg/s, min/median/75th/95th/99th consumer latency: 673/14086/24187/33064/46033 µs
    id: test-070938-160, time: 23.000s, sent: 13501 msg/s, received: 13875 msg/s, min/median/75th/95th/99th consumer latency: 3054/23130/25220/45241/50016 µs
    id: test-070938-160, time: 24.000s, sent: 13110 msg/s, received: 13138 msg/s, min/median/75th/95th/99th consumer latency: 1799/24372/29879/32923/38049 µs
    .....
    
    ```
  - 若要删除 PerfTest 实例，请使用
  
    ```
     kubectl delete pod perf-test
    ```
  
  - [PerfTest源码](https://github.com/rabbitmq/rabbitmq-perf-test)
   
- 个人服务调用rabbitmq，参考[rabbitmq教程](https://www.rabbitmq.com/getstarted.html)
## 问题
- rabbitmq 官方镜像下载不了

	因为众所周知的问题，需要设置 docker 的 mirror, 
	
	- 设置 `Preferences -> Docker Engine `

			{
			  "debug": true,
			  "experimental": false,
			  "registry-mirrors": [
			    "https://registry.docker-cn.com"
			  ]
			}
	- 查询镜像地址

			kubectl edit statefulset/rabbitmq-cluster-server
			
- 启动 node 调度失败
	- 发现 pod 启动 pending,发现报内存问题 

		`kubectl describe pod rabbitmq-cluster-server-0 `，报 `Insufficient memory` 内存不足，mac docker 的内存不足
		
	- 设置 `Preferences -> Resources`，调节 4GB

### 文档参考

- 使用文档： https://www.rabbitmq.com/kubernetes/operator/using-operator.html
- 部署文档： https://github.com/rabbitmq/cluster-operator
- 监控MQ: https://www.rabbitmq.com/kubernetes/operator/operator-monitoring.html
- 使用rabbitmq operator： https://www.rabbitmq.com/kubernetes/operator/using-operator.html#update