## Helm 安装 Redis-Operator


### 部署 Redis-Operator

- [源码地址](https://github.com/spotahome/redis-operator)
- 进入项目执行

	```
	helm install --name redisfailover charts/redisoperator
	```

### 发布redis服务

使用yaml发布redis服务，参考 [Redis-Operator部署.md](https://github.com/paradeum-team/operator-env/blob/main/redis-operator/Redis-Operator%E9%83%A8%E7%BD%B2.md)

### END