# 线下安装cert-manager

## 下载镜像推送到私有仓库

```
quay.io/jetstack/cert-manager-cainjector:v1.5.4
quay.io/jetstack/cert-manager-controller:v1.5.4
quay.io/jetstack/cert-manager-webhook:v1.5.4
quay.io/jetstack/cert-manager-ctl:v1.5.4
```

## 使用helm 方式安装cert-manager

在安装chart之前，必须先安装cert-manager CustomResourceDefinition资源。这是在一个单独的步骤中执行的，允许您轻松卸载和重新安装cert-manager，而不需要删除已安装的自定义资源。

```
wget https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.crds.yaml
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
helm pull jetstack/cert-manager --version=v1.5.4
```

安装 chart

```
helm install  cert-manager  cert-manager-v1.5.4.tgz -n cert-manager --create-namespace \
--set image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-controller \
--set webhook.image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-webhook \
--set cainjector.image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-cainjector \
--set startupapicheck.image.repository=registry.hisun.netwarps.com/jetstack/cert-manager-ctl
```


查看pod

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
curl -L -o kubectl-cert-manager.v1.5.4.tar.gz https://github.com/jetstack/cert-manager/releases/download/v1.5.4/kubectl-cert_manager-linux-amd64.tar.gz
tar xzf kubectl-cert-manager.v1.5.4.tar.gz
sudo mv kubectl-cert_manager /usr/local/bin
```
[kubectl-cert-manager.v1.5.4.tar.gz另一下载地址](https://pnode.solarfs.io/dn/file/df126f020af39a33d4df5d51067f142f/kubectl-cert-manager.v1.5.4.tar.gz)

## 参考 

https://artifacthub.io/packages/helm/wener/cert-manager

[https://cert-manager.io/docs/installation/kubernetes/](https://cert-manager.io/docs/installation/kubernetes/)

https://cert-manager.io/docs/configuration/ca/

https://www.jetstack.io/blog/securing-mysql-with-cert-manager/

