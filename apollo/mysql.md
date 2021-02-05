# mysql 

## 1. 新建 namespace

```
kubectl create namespace db
```

## 2、部署
**发布模板：**`mysql-deployment.yaml`

```
apiVersion: apps/v1 #// 描述RC对象的版本是v1
kind: Deployment  #// 声明Deployment对象
metadata: #// metadata中的是对此对象的描述信息
  name: mysql
  namespace: db
spec: #// spec中是对资源对象的具体描述
  replicas: 1 #// 创建1个副本
  selector: #// 选择器，用来选择对象的
    matchLabels:
      app: mysql
  template: #// 以下用来描述创建的pod的模版
    metadata:
      labels: #// 给以下打上标签，以供selector来选择
        app: mysql
    spec: #// 对pod模版的具体描述
      containers: #// 放入pod模版中的容器
      - name: mysql
        image: mysql:5.7
        imagePullPolicy: IfNotPresent
        args:
          - "--ignore-db-dir=lost+found"
        ports:
        - containerPort: 3306
          protocol: TCP
        env: #// 给该容器设置环境变量
        - name: MYSQL_ROOT_PASSWORD #// env中设置了mysql的root用户的密码为1234
          value: "root1234"
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: db
  labels:
    app: mysql
spec:
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 3306
      targetPort: 3306
  selector:
    app: mysql
```


```
kubectl apply -f mysql-deployment.yaml -n db
```