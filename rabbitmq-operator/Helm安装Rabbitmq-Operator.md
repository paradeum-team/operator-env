## Helm安装Rabbitmq-Operator

#### 1. 手动尝试使用Helm安装Rabbitmq-Cluster-Operator

由于官方还未提供标准的helm的安装方式，所以自己采取如下方式进行helm安装。

- Helm创建一个chart

  ```
  helm create rabbitmq
  
  ```
- [Rabbitmq-Cluster-Operator相关文件](https://github.com/rabbitmq/cluster-operator/tree/main/config)

   [rabbitmq文件下载](https://pnode.solarfs.io/dn/file/288dbb328faf3fc69a92dd77a95af3d6/rabbitmq-1.4.0.tgz)

- 将Rabbitmq-Cluster-Operator中相关的资源移动到新项目，目录如下：

     ```
     .
	├── crds
	│   └── rabbitmq.com_rabbitmqclusters.yaml
	├── namespace.yaml
	└── rabbitmq
	    ├── Chart.yaml
	    ├── charts
	    ├── templates
	    │   ├── _helpers.tpl
	    │   ├── cluster_role.yaml
	    │   ├── cluster_role_binding.yaml
	    │   ├── deployment.yaml
	    │   ├── rabbitmq.yaml
	    │   ├── role.yaml
	    │   ├── role_binding.yaml
	    │   └── service_account.yaml
	    └── values.yaml
    
     ```
     
 - 我将namespace和crd挪至与rabbitmq平级的目录。因为crd属于公共资源，所以我考虑是手动创建rabbitmq-operator的crd，这样的话使用helm uninstall不会删除crd（这个可以看需求）
 - 手动创建namespace，因为我希望rabbitmq这个服务是通过helm部署的，手动创建后可以指定namespace
 
#### 2.操作步骤

- 更改rabbitmq.com_rabbitmqclusters.yaml和deployment.yaml中所需要的镜像，使用内部镜像仓库。
	
  - 原镜像: rabbitmq:3.8.9-management 替换至  registry.hisun.netwarps.com/library/rabbitmq:3.8.9-management

  - 原镜像: rabbitmqoperator/cluster-operator:1.4.0 替换至  registry.hisun.netwarps.com/rabbitmqoperator/cluster-operator:1.4.0
  
- 创建namespace

 ```
 # namespace为rabbitmq-system
 kubectl apply -f namespace.yaml
 	
 ```

- 创建rabbitmq-operator的crd
	
 ```
  kubectl apply -f rabbitmq.com_rabbitmqclusters.yaml
  
 ```
 
- helm 安装rabbitmq-operator

 ```
 
 helm install rabbitmq ./rabbitmq -n rabbitmq-system

 ```
 
 - rabbitmq 为chart名字
 
 - ./rabbitmq 是创建的chart目录
 
 - rabbitmq-system 是namespace

- 验证

	```
	helm ls -n rabbitmq-system
    	
    	NAME    	NAMESPACE      	REVISION	UPDATED                             	STATUS  	CHART         	APP VERSION
    rabbitmq	rabbitmq-system	1       	2021-01-26 11:16:57.504597 +0800 CST	deployed	rabbitmq-0.9.0	3.8.9
	
	```


	
- 其他功能性验证和监控验证，参考之前两篇文档。
	
	[Mac-kubernetes-rabbitmq-operator.md](https://github.com/paradeum-team/operator-env/blob/main/rabbitmq-operator/Mac-kubernetes-rabbitmq-operator.md)
	
	[Prometheus-Operator监控rabbitmq实例.md](https://github.com/paradeum-team/operator-env/blob/main/rabbitmq-operator/Prometheus-Operator%E7%9B%91%E6%8E%A7rabbitmq%E5%AE%9E%E4%BE%8B.md)
 
- helm卸载安装

	```
	helm uninstall rabbitmq-n rabbitmq-system
	
	```
	
#### 3. rabbitmq-operator官方代码持续更新，有更好的helm方案，我们这边会使用官方的方案。
#### END
