## cert-manager 管理证书

### 创建 sonarqube namespace

```
kubectl create namespace sonarqube
```

### 安装

参考：[线下安装cert-manager](https://github.com/paradeum-team/operator-env/blob/main/cert-manager/%E7%BA%BF%E4%B8%8B%E5%AE%89%E8%A3%85cert-manager.md)

### 创建自签名 ClusterIssuer, 已经存在则忽略

```
cat >selfsigned-issuer.yaml<<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
  namespace: cert-manager
spec:
  selfSigned: {}
EOF
```

```
kubectl create secret tls ca-key-pair \
   --cert=ca.crt \
   --key=ca.key \
   --namespace=sonarqube
```

### 创建 sonarkube  ca-cert

参考：https://cert-manager.io/docs/usage/certificate/

创建 ca-cert.yaml

```
cat>sonar-apps164103-tls.yaml<<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: sonar-apps164103
  namespace: sonarqube
spec:
  dnsNames:
  - sonar.apps164103.hisun.local
  secretName: sonar-apps164103-tls
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  subject:
    organizations:
    - hisun
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  issuerRef:
    name: ca-issuer
    kind: Issuer
    # 使用内部自签名不改
    group: cert-manager.io
EOF
```

执行创建

```
kubectl apply -f ca-cert.yaml
```

查看创建好的 sonarqube-ca-cert

```
kubectl get secret -n sonarqube

NAME                              TYPE                                  DATA   AGE
ca-cert-ks58d                     Opaque                                1      9s
```

```
cat>ca-issuer.yaml<<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
  namespace: sonarqube
spec:
  ca:
    secretName: ca-cert-ks58d
EOF
```

```
kubectl apply -f ca-issuer.yaml
```

## 参考

https://docs.cert-manager.io/en/release-0.11/tasks/issuers/setup-ca.html

https://www.jetstack.io/blog/securing-mysql-with-cert-manager/