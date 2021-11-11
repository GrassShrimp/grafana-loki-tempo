resource "kubernetes_namespace" "tracing" {
  metadata {
    name = "tracing"
  }
  depends_on = [
    module.kind-istio-metallb
  ]
}
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.TEMPO_VERSION
  namespace  = kubernetes_namespace.tracing.metadata[0].name
  values = [
    <<EOF
    tempo:
      extraArgs:
        "distributor.log-received-traces": true
    EOF
  ]
}
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.LOKI_VERSION
  namespace  = kubernetes_namespace.tracing.metadata[0].name
}
resource "helm_release" "opentelemetry-collector" {
  name          = "opentelemetry-collector"
  repository    = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart         = "opentelemetry-collector"
  version       = var.OPENTELEMETRY_COLLECTOR_VERSION
  namespace     = kubernetes_namespace.tracing.metadata[0].name
  values = [
    <<EOF
    config:
      receivers:
        zipkin:
          endpoint: 0.0.0.0:9411
      exporters:
        otlp:
          endpoint: ${helm_release.tempo.name}.${kubernetes_namespace.tracing.metadata[0].name}.svc.cluster.local:55680
          tls:
            insecure: true
      service:
        pipelines:
          traces:
            receivers: [zipkin]
            exporters: [otlp]
    ports:
      otlp:
        enabled: true
        containerPort: 55680
        servicePort: 55680
        hostPort: 55680
        protocol: TCP
      zipkin:
        enabled: true
        containerPort: 9411
        servicePort: 9411
        hostPort: 9411
        protocol: TCP
    agentCollector:
      enabled: false
    standaloneCollector:
      enabled: true
    EOF
  ]
}
resource "helm_release" "fluent-bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = var.FLUENT_BIT_VERSION
  namespace  = kubernetes_namespace.tracing.metadata[0].name
  values = [
    <<EOF
    logLevel: trace
    config:
      service: |
        [SERVICE]
            Flush 1
            Daemon Off
            Log_Level trace
            Parsers_File custom_parsers.conf
            HTTP_Server On
            HTTP_Listen 0.0.0.0
            HTTP_Port {{ .Values.service.port }}
      inputs: |
        [INPUT]
            Name tail
            Path /var/log/containers/*istio-proxy*.log
            Parser cri
            Tag kube.*
            Mem_Buf_Limit 5MB
      outputs: |
        [OUTPUT]
            name loki
            match *
            host ${helm_release.loki.name}.${kubernetes_namespace.tracing.metadata[0].name}.svc
            port 3100
            tenant_id ""
            labels job=fluentbit
            label_keys $trace_id
            auto_kubernetes_labels on
      customParsers: |
        [PARSER]
            Name cri
            Format regex
            Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<message>.*)$
            Time_Key    time
            Time_Format %Y-%m-%dT%H:%M:%S.%L%z
    EOF
  ]
  depends_on = [
    helm_release.tempo,
    helm_release.loki,
  ]
}
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.GRAFANA_VERSION
  namespace  = kubernetes_namespace.tracing.metadata[0].name
  values = [
    <<EOF
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
        - name: Tempo
          type: tempo
          access: browser
          orgId: 1
          uid: tempo
          url: http://${helm_release.tempo.name}.${kubernetes_namespace.tracing.metadata[0].name}.svc:3100
          isDefault: true
          editable: true
        - name: Loki
          type: loki
          access: browser
          orgId: 1
          uid: loki
          url: http://${helm_release.loki.name}.${kubernetes_namespace.tracing.metadata[0].name}.svc:3100
          isDefault: false
          editable: true
          jsonData:
            derivedFields:
            - datasourceName: Tempo
              matcherRegex: "traceID=(\\w+)"
              name: TraceID
              url: "$${__value.raw}"
              datasourceUid: tempo
    env:
      JAEGER_AGENT_PORT: 6831
    adminUser: admin
    adminPassword: password
    service:
      type: ClusterIP
    EOF
  ]
}
resource "local_file" "grafana_route" {
  content  = <<-EOF
  apiVersion: networking.istio.io/v1beta1
  kind: Gateway
  metadata:
    name: grafana
  spec:
    selector:
      istio: ingressgateway
    servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
      - grafana.${module.kind-istio-metallb.ingress_ip_address}.nip.io
  ---
  apiVersion: networking.istio.io/v1beta1
  kind: VirtualService
  metadata:
    name: grafana
  spec:
    hosts:
    - grafana.${module.kind-istio-metallb.ingress_ip_address}.nip.io
    gateways:
    - grafana
    http:
    - route:
      - destination:
          host: ${helm_release.grafana.name}.${kubernetes_namespace.tracing.metadata[0].name}.svc.cluster.local
          port:
            number: 80
  EOF
  filename = "${path.root}/configs/grafana_route.yaml"
  provisioner "local-exec" {
    command = "kubectl --context ${module.kind-istio-metallb.config_context} apply -f ${self.filename} --namespace ${kubernetes_namespace.tracing.metadata[0].name}"
  }
}
