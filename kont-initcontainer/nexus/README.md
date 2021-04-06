### Nexus-InitContainer

#### 需求

- kont服务线下部署依赖nexus服务，需要提前初始化好jar包。
- 在nexus启动之前，使用初始化容器，将nexus使用到的库挂载到pvc中。

#### 构建init镜像

- data 数据下载

	```
	http://xxx:5145/dn/file/6b22f3cbfc702bda6abc39fa94c2c3e4/nexus-data.tar.gz > nexus-data.tar.gz
	
	```

- Dockerfile

	```
	FROM alpine:3.12.4

	COPY data data
	
	COPY init_run.sh init_run.sh
	
	RUN mkdir nexus-data
	
	```
- init_run.sh

	```
	#!/bin/sh
	is_empty_dir(){
	    return `ls -A nexus-data|wc -w`
	}
	
	if is_empty_dir nexus-data
	then
	    mv data/* nexus-data/
	    chown -R 200:200 nexus-data
	else
	    echo " nexus-data is not empty, data exist!"
	fi
	
	```
	
- 制作镜像
	
	```
	docker build -t xxx/library/nexus-init:2.14.9 .
	
	```
	
#### 遇到的问题

- 挂载nexus-data目录后，nexus无权限使用	

	```
	2021-03-09 06:57:10,638+0000 INFO  [main] *SYSTEM org.sonatype.nexus.bootstrap.Launcher - User: ?, en, ?
	2021-03-09 06:57:10,638+0000 INFO  [main] *SYSTEM org.sonatype.nexus.bootstrap.Launcher - CWD: /opt/sonatype/nexus
	2021-03-09 06:57:10,675+0000 INFO  [main] *SYSTEM org.sonatype.nexus.bootstrap.Launcher - TMP: /tmp
	2021-03-09 06:57:10,679+0000 INFO  [main] *SYSTEM org.sonatype.nexus.bootstrap.jetty.JettyServer - Starting
	2021-03-09 06:57:10,699+0000 INFO  [main] *SYSTEM org.sonatype.nexus.bootstrap.jetty.JettyServer - Applying configuration: file:/opt/sonatype/nexus/conf/jetty.xml
	2021-03-09 06:57:10,967+0000 INFO  [main] *SYSTEM org.sonatype.nexus.bootstrap.jetty.JettyServer - Applying configuration: file:/opt/sonatype/nexus/conf/jetty-requestlog.xml
	2021-03-09 06:57:10,988+0000 INFO  [jetty-main-1] *SYSTEM org.sonatype.nexus.bootstrap.jetty.JettyServer - Starting: org.eclipse.jetty.server.Server@53fdbc
	2021-03-09 06:57:10,992+0000 INFO  [jetty-main-1] *SYSTEM org.eclipse.jetty.server.Server - jetty-8.1.16.v20140903
	2021-03-09 06:57:11,591+0000 INFO  [jetty-main-1] *SYSTEM org.sonatype.nexus.webapp.WebappBootstrap - Initializing
	2021-03-09 06:57:11,592+0000 INFO  [jetty-main-1] *SYSTEM org.sonatype.nexus.webapp.WebappBootstrap - Using bootstrap launcher configuration
	2021-03-09 06:57:11,604+0000 WARN  [jetty-main-1] *SYSTEM org.sonatype.nexus.util.LockFile - Failed to write lock file
	java.io.FileNotFoundException: /sonatype-work/nexus.lock (Permission denied)
		at java.io.RandomAccessFile.open0(Native Method) ~[na:1.8.0_102]
		at java.io.RandomAccessFile.open(RandomAccessFile.java:316) ~[na:1.8.0_102]
		at java.io.RandomAccessFile.<init>(RandomAccessFile.java:243) ~[na:1.8.0_102]
		at org.sonatype.nexus.util.LockFile.lock(LockFile.java:92) ~[nexus-core-2.14.2-01.jar:2.14.2-01]
		at org.sonatype.nexus.webapp.WebappBootstrap.contextInitialized(WebappBootstrap.java:117) [classes/:na]
		at org.eclipse.jetty.server.handler.ContextHandler.callContextInitialized(ContextHandler.java:782) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.servlet.ServletContextHandler.callContextInitialized(ServletContextHandler.java:424) [jetty-servlet-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.server.handler.ContextHandler.startContext(ContextHandler.java:774) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.servlet.ServletContextHandler.startContext(ServletContextHandler.java:249) [jetty-servlet-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.webapp.WebAppContext.startContext(WebAppContext.java:1242) [jetty-webapp-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.server.handler.ContextHandler.doStart(ContextHandler.java:717) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.webapp.WebAppContext.doStart(WebAppContext.java:494) [jetty-webapp-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.util.component.AbstractLifeCycle.start(AbstractLifeCycle.java:64) [jetty-util-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.server.handler.HandlerWrapper.doStart(HandlerWrapper.java:95) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.util.component.AbstractLifeCycle.start(AbstractLifeCycle.java:64) [jetty-util-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.server.handler.HandlerCollection.doStart(HandlerCollection.java:229) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.util.component.AbstractLifeCycle.start(AbstractLifeCycle.java:64) [jetty-util-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.server.handler.HandlerWrapper.doStart(HandlerWrapper.java:95) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.server.Server.doStart(Server.java:282) [jetty-server-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.eclipse.jetty.util.component.AbstractLifeCycle.start(AbstractLifeCycle.java:64) [jetty-util-8.1.16.v20140903.jar:8.1.16.v20140903]
		at org.sonatype.nexus.bootstrap.jetty.JettyServer$JettyMainThread.run(JettyServer.java:247) [nexus-bootstrap-2.14.2-01.jar:2.14.2-01]
	2021-03-09 06:57:11,605+0000 ERROR [jetty-main-1] *SYSTEM org.sonatype.nexus.webapp.WebappBootstrap - Failed to initialize
	java.lang.IllegalStateException: Nexus work directory already in use: /sonatype-work
	
	```
	
- 解决办法

  - 这是因为挂载目录和运行容器的用户id（uid）和组id（gid）不同导致的。
  - 初始化镜像alpine:3.12.4默认是root用户，nexus工作目录默认是nexus权限。
  - 查看用户id
	  
	  	```
  		id nexus
  		uid=200(nexus) gid=200(nexus) groups=200(nexus)
  		```
  - 所以init_run.sh将data目录的数据移动到nexus-data，并且对nexus-data目录进行用户id和组id的修改。
	
  		```
  		chown -R 200:200 nexus-data
  		```
  		
  - 受此文档启发 [sonatype-nexus-docker-volume-error](https://stackoverflow.com/questions/36405434/sonatype-nexus-docker-volume-error)	
  	
#### Nexus部署模板新增如下内容
	
- nexus.yaml
	
	```
	initContainers:
    - name: init-volumes
      image: 'xxx/library/nexus-init:2.14.9'
      command:
        - sh
        - ./init_run.sh
      resources: {}
      volumeMounts:
        - name: nexus-data
          mountPath: /nexus-data
      terminationMessagePath: /dev/termination-log
      terminationMessagePolicy: File
      imagePullPolicy: IfNotPresent
      securityContext:
        capabilities: {}
        privileged: true

	```
- 默认登录账号密码：

	- admin/KontNexusP0ssword#	