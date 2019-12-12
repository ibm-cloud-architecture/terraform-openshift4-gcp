data "template_file" "install_config_yaml" {
  template = <<EOF
apiVersion: v1
baseDomain: ${var.base_domain}
compute:
- hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: ${var.node_count}
controlPlane:
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: ${var.master_count}
metadata:
  creationTimestamp: null
  name: ${var.cluster_name}
networking:
  clusterNetwork:
  - cidr: ${var.cluster_network_cidr}
    hostPrefix: ${var.cluster_network_host_prefix}
  machineCIDR: ${var.machine_cidr}
  networkType: OpenShiftSDN
  serviceNetwork:
  - ${var.service_network_cidr}
platform:
  gcp:
    projectID: ${var.project_id}
    region: ${var.gcp_region}
pullSecret: '${chomp(file(var.openshift_pull_secret))}'
sshKey: '${var.public_ssh_key}'
%{if var.airgapped["enabled"]}imageContentSources:
- mirrors:
  - ${var.airgapped["repository"]}
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - ${var.airgapped["repository"]}
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
%{endif}
EOF
}


resource "local_file" "install_config_yaml" {
  content  = data.template_file.install_config_yaml.rendered
  filename = "${local.installer_workspace}/install-config.yaml"
  depends_on = [
    null_resource.download_binaries,
  ]
}


data "template_file" "cloud-provider-config" {
  template = <<EOF
apiVersion: v1
data:
  config: |+
    [global]
    project-id      = ${var.project_id}
    regional        = true
    multizone       = true
    node-tags       = ${var.cluster_id}-worker
    subnetwork-name = ${var.cluster_id}-worker-subnet

kind: ConfigMap
metadata:
  creationTimestamp: null
  name: cloud-provider-config
  namespace: openshift-config
EOF
}

resource "local_file" "cloud-provider-config" {
  content  = data.template_file.cloud-provider-config.rendered
  filename = "${local.installer_workspace}/manifests/cloud-provider-config.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-config" {
  template = <<EOF
apiVersion: v1
data:
  install-config: |
    apiVersion: v1
    baseDomain: ${var.base_domain}
    compute:
    - hyperthreading: Enabled
      name: worker
      platform: {}
      replicas: ${var.node_count}
    controlPlane:
      hyperthreading: Enabled
      name: master
      platform:
        gcp:
          type: ${var.master_vm_type}
          zones:
${join("\n", formatlist("          - %v", var.zones))}
      replicas: ${var.master_count}
    metadata:
      creationTimestamp: null
      name: ${var.cluster_name}
    networking:
      clusterNetwork:
      - cidr: ${var.cluster_network_cidr}
        hostPrefix: ${var.cluster_network_host_prefix}
      machineCIDR: ${var.machine_cidr}
      networkType: OpenShiftSDN
      serviceNetwork:
      - ${var.service_network_cidr}
    platform:
      gcp:
        projectID: ${var.project_id}
        region: ${var.gcp_region}
    pullSecret: ""
    sshKey: '${var.public_ssh_key}'
kind: ConfigMap
metadata:
  name: cluster-config-v1
  namespace: kube-system
EOF
}

resource "local_file" "cluster-config" {
  content  = data.template_file.cluster-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-config.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}


data "template_file" "cluster-dns-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: DNS
metadata:
  creationTimestamp: null
  name: cluster
spec:
  baseDomain: ${var.base_domain}
  privateZone:
    id: ${var.cluster_id}-private-zone
  publicZone:
    id: ${var.public_dns_zone_name}
status: {}
EOF
}

resource "local_file" "cluster-dns-02-config" {
  content  = data.template_file.cluster-dns-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-dns-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-infrastructure-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Infrastructure
metadata:
  creationTimestamp: null
  name: cluster
spec:
  cloudConfig:
    key: config
    name: cloud-provider-config
status:
  apiServerInternalURI: https://api-int.${var.cluster_name}.${var.base_domain}:6443
  apiServerURL: https://api.${var.cluster_name}.${var.base_domain}:6443
  etcdDiscoveryDomain: ${var.cluster_name}.${var.base_domain}
  infrastructureName: ${var.cluster_id}
  platform: GCP
  platformStatus:
    gcp:
      projectID: ${var.project_id}
      region: ${var.gcp_region}
    type: GCP
EOF
}

resource "local_file" "cluster-infrastructure-02-config" {
  content  = data.template_file.cluster-infrastructure-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-infrastructure-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-ingress-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Ingress
metadata:
  creationTimestamp: null
  name: cluster
spec:
  domain: apps.${var.cluster_name}.${var.base_domain}
status: {}
EOF
}

resource "local_file" "cluster-ingress-02-config" {
  content  = data.template_file.cluster-ingress-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-ingress-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-network-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Network
metadata:
  creationTimestamp: null
  name: cluster
spec:
  clusterNetwork:
  - cidr: ${var.cluster_network_cidr}
    hostPrefix: ${var.cluster_network_host_prefix}
  externalIP:
    policy: {}
  networkType: OpenShiftSDN
  serviceNetwork:
  - ${var.service_network_cidr}
status: {}
EOF
}

resource "local_file" "cluster-network-02-config" {
  content  = data.template_file.cluster-network-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-network-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

# data "template_file" "etcd-host-service-endpoints-addresses" {
#   count    = var.master_count
#   template = <<EOF
#    - ip: ${element(var.etcd_ip_addresses, count.index)}
#      hostname: etcd-${count.index}
#  EOF
# }

# data "template_file" "etcd-host-service-endpoints" {
#   template = <<EOF
#  apiVersion: v1
#  kind: Endpoints
#  metadata:
#    name: host-etcd
#    namespace: openshift-etcd
#    annotations:
#      alpha.installer.openshift.io/dns-suffix: ocp42.azure.ncolon.xyz
#  subsets:
#  - addresses:
#  ${join("", data.template_file.etcd-host-service-endpoints-addresses.*.rendered)}
#    ports:
#    - name: etcd
#      port: 2379
#      protocol: TCP
#  EOF
# }

# resource "local_file" "etcd-host-service-endpoints" {
#   content  = data.template_file.etcd-host-service-endpoints.rendered
#   filename = "${local.installer_workspace}/manifests/etcd-host-service-endpoints.yaml"
#   depends_on = [
#     null_resource.download_binaries,
#     null_resource.generate_manifests,
#   ]
# }


data "template_file" "openshift-cluster-api_master-machines" {
  count    = var.master_count
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: Machine
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: master
    machine.openshift.io/cluster-api-machine-type: master
  name: ${var.cluster_id}-m-${count.index}
  namespace: openshift-machine-api
spec:
  metadata:
    creationTimestamp: null
  providerSpec:
    value:
      apiVersion: gcpprovider.openshift.io/v1beta1
      canIPForward: false
      credentialsSecret:
        name: gcp-cloud-credentials
      deletionProtection: false
      disks:
      - autoDelete: true
        boot: true
        image: ${var.cluster_id}-rhcos-image
        labels: null
        sizeGb: ${var.master_os_disk_size}
        type: pd-ssd
      kind: GCPMachineProviderSpec
      machineType: ${var.master_vm_type}
      metadata:
        creationTimestamp: null
      networkInterfaces:
      - network: ${var.cluster_id}-network
        subnetwork: ${var.cluster_id}-master-subnet
      projectID: ${var.project_id}
      region: ${var.gcp_region}
      serviceAccounts:
      - email: ${var.cluster_id}-m@${var.project_id}.iam.gserviceaccount.com
        scopes:
        - https://www.googleapis.com/auth/cloud-platform
      tags:
      - ${var.cluster_id}-master
      targetPools:
      - ${var.cluster_id}-api
      userDataSecret:
        name: master-user-data
      zone: ${var.zones[count.index % length(var.zones)]}
status: {}
EOF
}

# resource "local_file" "openshift-cluster-api_master-machines" {
#   count    = var.master_count
#   content  = element(data.template_file.openshift-cluster-api_master-machines.*.rendered, count.index)
#   filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_master-machines-${count.index}.yaml"
#   depends_on = [
#     null_resource.download_binaries,
#     null_resource.generate_manifests,
#   ]
# }


data "template_file" "openshift-cluster-api_worker-machineset" {
  count    = var.node_count
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
  name: ${var.cluster_id}-w-${replace(var.zones[count.index % length(var.zones)], "${var.gcp_region}-", "")}
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
      machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-w-${replace(var.zones[count.index % length(var.zones)], "${var.gcp_region}-", "")}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-w-${replace(var.zones[count.index % length(var.zones)], "${var.gcp_region}-", "")}
    spec:
      metadata:
        creationTimestamp: null
      providerSpec:
        value:
          apiVersion: gcpprovider.openshift.io/v1beta1
          canIPForward: false
          credentialsSecret:
            name: gcp-cloud-credentials
          deletionProtection: false
          disks:
          - autoDelete: true
            boot: true
            image: ${var.cluster_id}-rhcos-image
            labels: null
            sizeGb: ${var.worker_os_disk_size}
            type: pd-ssd
          kind: GCPMachineProviderSpec
          machineType: ${var.worker_vm_type}
          metadata:
            creationTimestamp: null
          networkInterfaces:
          - network: ${var.cluster_id}-network
            subnetwork: ${var.cluster_id}-worker-subnet
          projectID: ${var.project_id}
          region: ${var.gcp_region}
          serviceAccounts:
          - email: ${var.cluster_id}-w@${var.project_id}.iam.gserviceaccount.com
            scopes:
            - https://www.googleapis.com/auth/cloud-platform
          tags:
          - ${var.cluster_id}-worker
          userDataSecret:
            name: worker-user-data
          zone: ${var.zones[count.index % length(var.zones)]}
status:
  replicas: 0
EOF
}

resource "local_file" "openshift-cluster-api_worker-machineset" {
  count    = var.master_count
  content  = element(data.template_file.openshift-cluster-api_worker-machineset.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machineset-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "openshift-cluster-api_infra-machineset" {
  count    = var.infra_count
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
  name: ${var.cluster_id}-i-${replace(var.zones[count.index % length(var.zones)], "-${var.gcp_region}", "")}
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
      machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-i-${replace(var.zones[count.index % length(var.zones)], "-${var.gcp_region}", "")}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-i-${replace(var.zones[count.index % length(var.zones)], "-${var.gcp_region}", "")}
    spec:
      metadata:
        creationTimestamp: null
      providerSpec:
        value:
          apiVersion: gcpprovider.openshift.io/v1beta1
          canIPForward: false
          credentialsSecret:
            name: gcp-cloud-credentials
          deletionProtection: false
          disks:
          - autoDelete: true
            boot: true
            image: ${var.cluster_id}-rhcos-image
            labels: null
            sizeGb: ${var.infra_os_disk_size}
            type: pd-ssd
          kind: GCPMachineProviderSpec
          machineType: ${var.infra_vm_type}
          metadata:
            creationTimestamp: null
          networkInterfaces:
          - network: ${var.cluster_id}-network
            subnetwork: ${var.cluster_id}-worker-subnet
          projectID: ${var.project_id}
          region: ${var.gcp_region}
          serviceAccounts:
          - email: ${var.cluster_id}-w@${var.project_id}.iam.gserviceaccount.com
            scopes:
            - https://www.googleapis.com/auth/cloud-platform
          tags:
          - ${var.cluster_id}-worker
          userDataSecret:
            name: worker-user-data
          zone: ${var.zones[count.index % length(var.zones)]}
status:
  replicas: 0
EOF
}

resource "local_file" "openshift-cluster-api_infra-machineset" {
  count    = var.infra_count
  content  = element(data.template_file.openshift-cluster-api_infra-machineset.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_infra-machineset-${count.index}.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "ingresscontroller-default" {
  template = <<EOF
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  finalizers:
  - ingresscontroller.operator.openshift.io/finalizer-ingresscontroller
  name: default
  namespace: openshift-ingress-operator
spec:
  endpointPublishingStrategy:
    loadBalancer:
      scope: ${var.airgapped["enabled"] ? "Internal" : "External"}
    type: LoadBalancerService
  replicas: 2
%{if var.infra_count > 0}  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
%{endif}
EOF
}


resource "local_file" "ingresscontroller-default" {
  content  = data.template_file.ingresscontroller-default.rendered
  filename = "${local.installer_workspace}/openshift/99_default_ingress_controller.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-scheduler-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  mastersSchedulable: false
  policy:
    name: ""
status: {}
EOF
}

resource "local_file" "cluster-scheduler-02-config" {
  content  = data.template_file.cluster-scheduler-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-scheduler-02-config.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cluster-monitoring-configmap" {
  template = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |+
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    grafana:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
EOF
}

resource "local_file" "cluster-monitoring-configmap" {
  count    = var.infra_count > 0 ? 1 : 0
  content  = data.template_file.cluster-monitoring-configmap.rendered
  filename = "${local.installer_workspace}/openshift/99_cluster-monitoring-configmap.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}


data "template_file" "configure-image-registry-job" {
  template = <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: infra
  namespace: openshift-image-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:ibm-patch-cluster-storage
rules:
- apiGroups: ['imageregistry.operator.openshift.io']
  resources: ['configs']
  verbs:     ['get','patch']
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:ibm-patch-cluster-storage
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:ibm-patch-cluster-storage
subjects:
  - kind: ServiceAccount
    name: default
    namespace: openshift-image-registry
---
apiVersion: batch/v1
kind: Job
metadata:
  name: ibm-configure-image-registry
  namespace: openshift-image-registry
spec:
  parallelism: 1
  completions: 1
  template:
    metadata:
      name: configure-image-registry
      labels:
        app: configure-image-registry
    serviceAccountName: infra
    spec:
      containers:
      - name:  client
        image: quay.io/openshift/origin-cli:latest
        command: ["/bin/sh","-c"]
        args: ["while ! /usr/bin/oc get configs cluster >/dev/null 2>&1; do sleep 1;done;/usr/bin/oc patch configs cluster --type merge --patch '{\"spec\": {\"defaultRoute\": true,%{if var.infra_count > 0}\"nodeSelector\": {\"node-role.kubernetes.io/infra\": \"\"}%{endif}}}'"]
      restartPolicy: Never
EOF
}

resource "local_file" "configure-image-registry-job" {
  content  = data.template_file.configure-image-registry-job.rendered
  filename = "${local.installer_workspace}/openshift/99_configure-image-registry-job.yml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "airgapped_registry_upgrades" {
  count    = var.airgapped["enabled"] ? 1 : 0
  template = <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: airgapped
spec:
  repositoryDigestMirrors:
  - mirrors:
    - ${var.airgapped["repository"]}
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - ${var.airgapped["repository"]}
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF
}

resource "local_file" "airgapped_registry_upgrades" {
  count    = var.airgapped["enabled"] ? 1 : 0
  content  = element(data.template_file.airgapped_registry_upgrades.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_airgapped_registry_upgrades.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}

data "template_file" "cloud-creds-secret" {
  template = <<EOF
kind: Secret
apiVersion: v1
metadata:
  namespace: kube-system
  name: gcp-credentials
data:
  service_account.json: ${var.serviceaccount_encoded}
EOF
}

resource "local_file" "cloud-creds-secret" {
  content  = data.template_file.cloud-creds-secret.rendered
  filename = "${local.installer_workspace}/openshift/99_cloud-creds-secret.yaml"
  depends_on = [
    null_resource.download_binaries,
    null_resource.generate_manifests,
  ]
}
