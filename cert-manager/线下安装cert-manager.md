# 线下安装cert-manager

## 下载镜像推送到私有仓库

```
quay.io/jetstack/cert-manager-cainjector:v1.3.1
quay.io/jetstack/cert-manager-controller:v1.3.1
quay.io/jetstack/cert-manager-webhook:v1.3.1
```

## 使用helm 方式安装cert-manager

在安装chart之前，必须先安装cert-manager CustomResourceDefinition资源。这是在一个单独的步骤中执行的，允许您轻松卸载和重新安装cert-manager，而不需要删除已安装的自定义资源。

```
wget https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.crds.yaml
kubectl apply -f cert-manager.crds.yaml
```

创建namespace

```
kubectl create namespace cert-manager
```

下载 chart

```
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm pull jetstack/cert-manager --version=v1.3.1
```

安装 chart

```
helm install  cert-manager  cert-manager-v1.3.1.tgz -n cert-manager \
--set image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-controller \
--set webhook.image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-webhook \
--set cainjector.image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-cainjector
```

参考：

https://cert-manager.io/docs/installation/kubernetes/#

https://artifacthub.io/packages/helm/wener/cert-manager

## 使用yaml方式安装cert-manager
### 下载部署yaml

```
wget https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml
```

### 改image 源

```
sed -i 's/quay.io/registry.hisun.netwarps.com/g' cert-manager.yaml
```

### 部署

```
kubectl apply -f cert-manager.yaml
```

### 查看pod

```
kubectl get pods --namespace cert-manager
```

## 验证安装

### 创建一个Issuer验证 webhook 可以正常工作

```
cat <<EOF > test-resources.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
EOF
```

```
kubectl apply -f test-resources.yaml
```

刚安装完cert-manager 执行验证test-resources 报错

```
Error from server (InternalError): error when creating "test-resources.yaml": Internal error occurred: failed calling webhook "webhook.cert-manager.io": Post "https://cert-manager-webhook.cert-manager.svc:443/mutate?timeout=10s": x509: certificate has expired or is not yet valid: current time 2021-04-20T11:09:21Z is before 2021-04-20T14:45:51Z
Error from server (InternalError): error when creating "test-resources.yaml": Internal error occurred: failed calling webhook "webhook.cert-manager.io": Post "https://cert-manager-webhook.cert-manager.svc:443/mutate?timeout=10s": x509: certificate has expired or is not yet valid: current time 2021-04-20T11:09:21Z is before 2021-04-20T14:45:51Z
```

因为本地时区是上海时区，跟 cert-manager-webhook 时区默认为美国时区，有时差，所以当前时间在 证书生效前，导致证书验证失败，暂时没找到好的解决方法，等几个小时后证书生效再访问

### 检查新创建的证书的状态。在cert-manager处理证书请求之前，您可能需要等待几秒钟。

```
kubectl describe certificate -n cert-manager-test

...
Events:
  Type    Reason     Age    From          Message
  ----    ------     ----   ----          -------
  Normal  Issuing    2m23s  cert-manager  Issuing certificate as Secret does not exist
  Normal  Generated  2m23s  cert-manager  Stored new private key in temporary Secret resource "selfsigned-cert-hfhdd"
  Normal  Requested  2m23s  cert-manager  Created new CertificateRequest resource "selfsigned-cert-j68cv"
  Normal  Issuing    2m23s  cert-manager  The certificate has been successfully issued
```

### 删除测试资源

```
kubectl delete -f test-resources.yaml
```

### 创建集群自重命名 Issuer

```
cat>selfsigned-issuer.yaml<<EOF
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
kubectl apply -f selfsigned-issuer.yaml
```

## 安装kubectl cert-manager 插件

```
curl -L -o kubectl-cert-manager.v1.3.1.tar.gz https://github.com/jetstack/cert-manager/releases/download/v1.3.1/kubectl-cert_manager-linux-amd64.tar.gz
tar xzf kubectl-cert-manager.v1.3.1.tar.gz
sudo mv kubectl-cert_manager /usr/local/bin
```

## 参考 

[https://cert-manager.io/docs/installation/kubernetes/](https://cert-manager.io/docs/installation/kubernetes/)

https://cert-manager.io/docs/configuration/ca/

https://www.jetstack.io/blog/securing-mysql-with-cert-manager/

