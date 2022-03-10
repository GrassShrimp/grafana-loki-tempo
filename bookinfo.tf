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
data "curl" "bookinfoYaml" {
  http_method = "GET"
  uri         = "https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml"
}
data "kubectl_file_documents" "bookinfoYaml" {
    content = data.curl.bookinfoYaml.response
}
resource "kubectl_manifest" "bookinfo" {
  for_each  = data.kubectl_file_documents.bookinfoYaml.manifests
  yaml_body = each.value
  override_namespace = kubernetes_namespace.bookinfo.metadata[0].name
}
resource "kubectl_manifest" "bookinfo_route" {
  for_each = {
    bookinfo-gateway        = <<EOF
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
    EOF
    bookinfo-virtualservice = <<EOF
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
  }
  yaml_body          = each.value
  override_namespace = kubernetes_namespace.bookinfo.metadata[0].name
  depends_on = [
    kubectl_manifest.bookinfo
  ]
}
