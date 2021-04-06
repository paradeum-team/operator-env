#### 初始化redis数据

#### 一、说明

- kont服务是通过API方式进行redis数据初始化
- 我们通过curl命令的方式进行api请求，所以需要制作一个基础镜像。
- 基础镜像为： 
	- registry.hisun.netwarps.com/library/kont-curl:0.0.1

#### 二、Dockerfile

```
FROM alpine
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories
RUN apk add --update curl && rm -rf /var/cache/apk/*

```

- docker build -t registry.hisun.netwarps.com/library/kont-curl:0.0.1 .

#### 三、在kont-meta服务中初始化redis

```
initContainers:
  - name: init-redis
	 image: 'registry.hisun.netwarps.com/library/kont-curl:0.0.1'
	 command:
	   - sh
	   - '-c'
	   - >-
	     curl -X POST --header 'Content-Type: application/json' --header
	     'Accept: application/json' -d '{}'
	     'http://kont-base.kont:19301/base/publicCode/getAllRedisData'

```

#### END