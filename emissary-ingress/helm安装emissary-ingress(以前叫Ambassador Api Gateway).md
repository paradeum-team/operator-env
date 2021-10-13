# helm安装emissary-ingress(以前叫Ambassador Api Gateway)

Emissary-Ingress（以前称为大使 API 网关）是一个开源的 Kubernetes 原生 API 网关 + 第 7 层负载均衡器 + Kubernetes Ingress 构建在 Envoy Proxy上。 Emissary Ingress 是一个 CNCF 孵化项目。

## 添加 chart repo

```
helm repo add emissary-ingress https://app.getambassador.io
helm repo update
```

## 下载 chart

```
helm pull --devel emissary-ingress/emissary-ingress
```

## 安装

```
helm upgrade --install emissary-ingress emissary-ingress-7.1.8-ea.tgz -n ambassador --create-namespace -f values.yaml
```