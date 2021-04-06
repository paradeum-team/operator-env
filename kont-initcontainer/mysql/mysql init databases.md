### Mysql init databases


#### 需求

- mysql初始化创建kont服务相关的数据库，空库。
- 创建kont服务需要使用的账号，密码，相关账号权限。

#### 更新mysql-cluster.yaml


```
apiVersion: mysql.presslabs.org/v1alpha1
kind: MysqlCluster
metadata:
  name: mysql-cluster
spec:
  replicas: 2
  secretName: my-secret
  volumeSpec:
    persistentVolumeClaim:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
  mysqlConf:
    lower_case_table_names: 1
  initFileExtraSQL:
    - "CREATE DATABASE IF NOT EXISTS base_dev CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
    - "CREATE USER IF NOT EXISTS base_dev@'%' IDENTIFIED BY 'Hisun.11'"
    - "GRANT ALL privileges on base_dev.* TO base_dev@'%' identified by 'Hisun.11'"
    - "GRANT ALL privileges on base_dev.* TO base_dev@'localhost' identified by 'Hisun.11'"
    - "CREATE DATABASE IF NOT EXISTS activiti_dev CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
    - "CREATE USER IF NOT EXISTS activiti_dev@'%' IDENTIFIED BY 'Hisun.11'"
    - "GRANT ALL privileges on activiti_dev.* TO activiti_dev@'%' identified by 'Hisun.11'"
    - "GRANT ALL privileges on activiti_dev.* TO activiti_dev@'localhost' identified by 'Hisun.11'"
    - "CREATE DATABASE IF NOT EXISTS kont_dev CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
    - "CREATE USER IF NOT EXISTS kont_dev@'%' IDENTIFIED BY 'Hisun.11'"
    - "GRANT ALL privileges on kont_dev.* TO kont_dev@'%' identified by 'Hisun.11'"
    - "GRANT ALL privileges on kont_dev.* TO kont_dev@'localhost' identified by 'Hisun.11'"
    - "CREATE DATABASE IF NOT EXISTS metadata_dev CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
    - "CREATE USER IF NOT EXISTS metadata_dev@'%' IDENTIFIED BY 'Hisun.11'"
    - "GRANT ALL privileges on metadata_dev.* TO metadata_dev@'%' identified by 'Hisun.11'"
    - "GRANT ALL privileges on metadata_dev.* TO metadata_dev@'localhost' identified by 'Hisun.11'"
    - "CREATE DATABASE IF NOT EXISTS xxl_job CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
    - "CREATE USER IF NOT EXISTS xxl_job@'%' IDENTIFIED BY 'Hisun.11'"
    - "GRANT ALL privileges on xxl_job.* TO xxl_job@'%' identified by 'Hisun.11'"
    - "GRANT ALL privileges on xxl_job.* TO xxl_job@'localhost' identified by 'Hisun.11'"
    - "flush privileges"
    - "CREATE DATABASE IF NOT EXISTS apolloconfigdb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
    - "CREATE DATABASE IF NOT EXISTS apolloportaldb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci'"
```

####  注意

- initFileExtraSQL

   - 数组，字符串类型。语句后面不支持分号