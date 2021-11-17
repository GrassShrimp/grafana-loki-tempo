# grafana-loki-tempo

This demo is reference by [How Istio, Tempo, and Loki speed up debugging for microservices](https://grafana.com/blog/2021/08/31/how-istio-tempo-and-loki-speed-up-debugging-for-microservices/), but implement via terraform instead of apply file of yaml directly

## Prerequisites

- [terraform](https://www.terraform.io/downloads.html)
- [docker](https://www.docker.com/products/docker-desktop)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)

## Usage

initialize terraform module

```bash
$ terraform init
```

create k8s cluster with kind, and install all components - istio, metallb, grafana, loki, tempo, fluentbit, and opentelemetry-collector, as well as a demo project - bookinfo

```
$ terraform apply -auto-approve
```

after the excution done, please open below urls in browser

- [grafana.127.0.0.1.nip.io](grafana.127.0.0.1.nip.io)
- [bookinfo.127.0.0.1.nip.io](bookinfo.127.0.0.1.nip.io)

the default account of grafana is "admin", with password is "password"

after all, please follow the remaind scenario "Test It" in [How Istio, Tempo, and Loki speed up debugging for microservices](https://grafana.com/blog/2021/08/31/how-istio-tempo-and-loki-speed-up-debugging-for-microservices/) for test trace microservice

![preview-1](https://github.com/GrassShrimp/grafana-loki-tempo/blob/master/preview-1.png)
![preview-2](https://github.com/GrassShrimp/grafana-loki-tempo/blob/master/preview-2.png)
