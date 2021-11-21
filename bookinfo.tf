resource "kubernetes_namespace" "bookinfo" {
  metadata {
    name = "bookinfo"
    labels = {
      "istio-injection" = "enabled"
    }
  }
  depends_on = [
    module.kind-istio-metallb
  ]
}
resource "null_resource" "bookinfo" {
  triggers = {
    context = module.kind-istio-metallb.config_context
    namespace = kubernetes_namespace.bookinfo.metadata[0].name
  }
  provisioner "local-exec" {
    command = "kubectl --context ${self.triggers.context} apply -f https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml --namespace ${self.triggers.namespace}"
  }
  provisioner "local-exec" {
    when = destroy
    command = "kubectl --context ${self.triggers.context} delete -f https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml --namespace ${self.triggers.namespace}"
  }
}
resource "local_file" "bookinfo_route" {
  content  = <<-EOF
  apiVersion: networking.istio.io/v1beta1
  kind: Gateway
  metadata:
    name: bookinfo-gateway
  spec:
    selector:
      istio: ingressgateway
    servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
      - bookinfo.${module.kind-istio-metallb.ingress_ip_address}.nip.io
  ---
  apiVersion: networking.istio.io/v1beta1
  kind: VirtualService
  metadata:
    name: bookinfo-virtualservice
  spec:
    hosts:
    - bookinfo.${module.kind-istio-metallb.ingress_ip_address}.nip.io
    gateways:
    - tracing/bookinfo-gateway
    - bookinfo-gateway
    http:
    - match:
      - uri:
          prefix: "/"
      route:
      - destination:
          host: productpage.bookinfo.svc.cluster.local
          port:
            number: 9080
  EOF
  filename = "${path.root}/configs/bookinfo_route.yaml"
  provisioner "local-exec" {
    command = "kubectl --context ${module.kind-istio-metallb.config_context} apply -f ${self.filename} --namespace ${kubernetes_namespace.bookinfo.metadata[0].name}"
  }
  depends_on = [
    null_resource.bookinfo
  ]
}
