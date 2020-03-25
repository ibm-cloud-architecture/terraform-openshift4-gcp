locals {
  installer_workspace     = "${path.root}/installer-files"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}"
  cluster_nr              = element(split("-", "${var.cluster_id}"), 1)
}

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
test -e ${local.installer_workspace} || mkdir ${local.installer_workspace}
case $(uname -s) in
  Darwin)
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${local.installer_workspace} -A 'openshift-install-mac-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-install-mac-4*.tar.gz -C ${local.installer_workspace}
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${local.installer_workspace} -A 'openshift-client-mac-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-client-mac-4*.tar.gz -C ${local.installer_workspace}
    wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -O ${local.installer_workspace}/jq > /dev/null 2>&1\
    ;;
  Linux)
    wget -r -l1 -np -nd -q ${local.installer_workspace} -P ${local.installer_workspace} -A 'openshift-install-linux-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-install-linux-4*.tar.gz -C ${local.installer_workspace}
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${local.installer_workspace} -A 'openshift-client-linux-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-client-linux-4*.tar.gz -C ${local.installer_workspace}
    wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O ${local.installer_workspace}/jq
    ;;
  *)
    exit 1;;
esac
chmod u+x ${local.installer_workspace}/jq
rm -f ${local.installer_workspace}/*.tar.gz ${local.installer_workspace}/robots*.txt* ${local.installer_workspace}/README.md
if [[ "${var.airgapped["enabled"]}" == "true" ]]; then
  ${local.installer_workspace}/oc adm release extract -a ${path.root}/${var.openshift_pull_secret} --command=openshift-install ${var.airgapped["repository"]}:${var.openshift_version}
  mv ${path.root}/openshift-install ${local.installer_workspace}
fi
EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${local.installer_workspace}"
  }

}


resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
  ]

  provisioner "local-exec" {
    command = <<EOF
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} create manifests
rm ${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machineset-*
rm ${local.installer_workspace}/openshift/99_openshift-cluster-api_master-machines-*
EOF
  }
}

# see templates.tf for generation of yaml config files

resource "null_resource" "generate_ignition" {
  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
    null_resource.generate_manifests,
    local_file.cluster-infrastructure-02-config,
    local_file.cluster-dns-02-config,
    local_file.cloud-provider-config,
    # local_file.openshift-cluster-api_master-machines,
    local_file.openshift-cluster-api_worker-machineset,
    local_file.openshift-cluster-api_infra-machineset,
    local_file.ingresscontroller-default,
    local_file.cloud-creds-secret,
    local_file.cluster-scheduler-02-config,
    local_file.cluster-monitoring-configmap,
    # local_file.private-cluster-outbound-service,
  ]

  provisioner "local-exec" {
    command = <<EOF
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} create ignition-configs
${local.installer_workspace}/jq '.infraID="${var.cluster_id}"' ${local.installer_workspace}/metadata.json > /tmp/metadata.json
mv /tmp/metadata.json ${local.installer_workspace}/metadata.json
EOF
  }
}

resource "google_storage_bucket" "ignition" {
  name = "${var.cluster_id}-ignition"
}

resource "google_storage_bucket_object" "ignition_bootstrap" {
  bucket = google_storage_bucket.ignition.name
  name   = "bootstrap.ign"
  source = "${local.installer_workspace}/bootstrap.ign"

  depends_on = [
    null_resource.generate_ignition
  ]
}

data "google_storage_object_signed_url" "bootstrap_ignition_url" {
  bucket   = google_storage_bucket.ignition.name
  path     = "bootstrap.ign"
  duration = "24h"

  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "google_storage_bucket_object" "ignition_master" {
  bucket = google_storage_bucket.ignition.name
  name   = "master.ign"
  source = "${local.installer_workspace}/master.ign"

  depends_on = [
    null_resource.generate_ignition
  ]
}

data "google_storage_object_signed_url" "master_ignition_url" {
  bucket   = google_storage_bucket.ignition.name
  path     = "master.ign"
  duration = "24h"

  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "google_storage_bucket_object" "ignition_worker" {
  bucket = google_storage_bucket.ignition.name
  name   = "worker.ign"
  source = "${local.installer_workspace}/worker.ign"

  depends_on = [
    null_resource.generate_ignition
  ]
}

data "google_storage_object_signed_url" "worker_ignition_url" {
  bucket   = google_storage_bucket.ignition.name
  path     = "worker.ign"
  duration = "24h"

  depends_on = [
    null_resource.generate_ignition
  ]
}

data "ignition_config" "bootstrap_redirect" {
  replace {
    source = data.google_storage_object_signed_url.bootstrap_ignition_url.signed_url
  }
}

data "ignition_config" "master_redirect" {
  replace {
    source = data.google_storage_object_signed_url.master_ignition_url.signed_url
  }
}

data "ignition_config" "worker_redirect" {
  replace {
    source = data.google_storage_object_signed_url.worker_ignition_url.signed_url
  }
}
