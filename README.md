# OpenShift 4 UPI on Google Cloud

This [terraform](http://terraform.io) implementation will deploy OpenShift 4.x into a GCP VPC, with two subnets for controlplane and worker nodes.  Traffic to the master nodes is handled via a pair of loadbalancers, one for internal traffic and another for external API traffic.  Application loadbalancing is handled by a third loadbalancer that talks to the router pods on the infra or worker nodes.  Worker, Infra and Master nodes are deployed across 3 Availability Zones


# Prerequisites

1.  [Enable Service APIs](https://github.com/openshift/installer/blob/master/docs/user/gcp/apis.md)
2.  [Configure DNS](https://github.com/openshift/installer/blob/master/docs/user/gcp/dns.md) 
3.  [Create GCP Service Account](https://github.com/openshift/installer/blob/master/docs/user/gcp/iam.md) with proper IAM roles 


# Minimal TFVARS file

```terraform
gcp_project_id      = "hsbc-261614"
gcp_region          = "us-central1"
cluster_name        = "ocp42"

# From Prereq. Step #2
gcp_public_dns_zone_name = "gcp-ncolon-xyz"
base_domain              = "gcp.ncolon.xyz"

# From Prereq. Step #3
gcp_service_account = "credentials.json"
```



# Customizable Variables

| Variable                              | Description                                                    | Default         | Type   |
| ------------------------------------- | -------------------------------------------------------------- | --------------- | ------ |
| gcp_project_id   | The target GCP project for the cluster. | -               | string |
| gcp_service_account    | Path to JSON file with details for the GCP APIs service account (from Prereq Step #3) | -               | string |
| gcp_region             | he target GCP region for the cluster | -               | string |
| gcp_extra_labels   | Extra GCP labels to be applied to created resources          | {}             | map |
| cluster_name                | Cluster Identifier                                                       | -               | string |
| openshift_master_count                | Number of master nodes to deploy                               | 3               | string |
| openshift_worker_count                | Number of worker nodes to deploy                               | 3               | string |
| openshift_infra_count                 | Number of infra nodes to deploy                                | 0              | string |
| machine_cidr                          | CIDR for OpenShift VNET                                        | 10.0.0.0/16     | string |
| base_domain                           | DNS name for your deployment                                   | -               | string |
| gcp_public_dns_zone_name | The name of the public DNS zone to use for this cluster (from Prereq Step #2) | -               | string |
| gcp_bootstrap_instance_type | Size of bootstrap VM                                           | n1-standard-4 | string |
| gcp_master_instance_type | Size of master node VMs                                        | n1-standard-4 | string |
| gcp_infra_instance_type | Size of infra node VMs                                         | n1-standard-4 | string |
| gcp_worker_instance_type | Sizs of worker node VMs                                        | n1-standard-4 | string |
| openshift_cluster_network_cidr        | CIDR for Kubernetes pods                                       | 10.128.0.0/14   | string |
| openshift_cluster_network_host_prefix | Detemines the number of pods a node can host.  23 gives you 510 pods per node. | 23 | string |
| openshift_service_network_cidr        | CIDR for Kubernetes services                                   | 172.30.0.0/16   | string |
| openshift_pull_secret                 | path to filename that holds your OpenShift [pull-secret](https://cloud.redhat.com/openshift/install/azure/installer-provisioned) | - | string |
| gcp_master_os_disk_size | Size of master node root volume                                | 1024            | string |
| gcp_worker_os_disk_size | Size of worker node root volume                                | 128             | string |
| gcp_infra_os_disk_size | Size of infra node root volume                                 | 128             | string |
| gcp_image_uri          | URL of the CoreOS image. Can be found [here](https://github.com/openshift/installer/blob/master/data/data/rhcos.json) | [URL](https://storage.googleapis.com/rhcos/rhcos/42.80.20191002.0.tar.gz) | string |
| openshift_version                     | Version of OpenShift to deploy.                                | latest          | strig |
|gcp_bootstrap_enabled|Setting this to false allows the bootstrap resources to be disabled|true|bool|
|gcp_bootstrap_lb|Setting this to false allows the bootstrap resources to be removed from the cluster load balancers|true|bool|
| airgapped                             | Configuration for an AirGapped environment                     | [AirGapped](airgapped.md) default is `false`| map |


# Deploy with Terraform

1. Clone github repository
```bash
git clone https://github.com/ibm-cloud-architecture/terraform-openshift4-gcp.git
```

2. Create your `terraform.tfvars` file

3. Deploy with terraform
```bash
$ terraform init
$ terraform plan
$ terraform apply
```
4.  Destroy bootstrap node
```bash
$ TF_VAR_gcp_bootstrap_enabled=false terraform apply
```
5.  To access your cluster
```bash
 $ export KUBECONFIG=$PWD/installer-files/auth/kubeconfig
 $ oc get nodes
NAME                                                         STATUS   ROLES          AGE   VERSION
ocp42-a26ek-master-0.us-central1-a.c.hsbc-261614.internal    Ready    master         95m   v1.14.6+31a56cf75
ocp42-a26ek-master-1.us-central1-b.c.hsbc-261614.internal    Ready    master         95m   v1.14.6+31a56cf75
ocp42-a26ek-master-2.us-central1-c.c.hsbc-261614.internal    Ready    master         95m   v1.14.6+31a56cf75
ocp42-a26ek-w-a-xrgvb.us-central1-a.c.hsbc-261614.internal   Ready    worker         91m   v1.14.6+31a56cf75
ocp42-a26ek-w-b-h72ss.us-central1-b.c.hsbc-261614.internal   Ready    worker         90m   v1.14.6+31a56cf75
ocp42-a26ek-w-c-4x64c.us-central1-c.c.hsbc-261614.internal   Ready    worker         90m   v1.14.6+31a56cf75
```



# Infra and Worker Node Deployment

Deployment of Openshift Worker and Infra nodes is handled by the machine-operator-api cluster operator.

```bash
$ oc get machineset -n openshift-machine-api
NAME              DESIRED   CURRENT   READY   AVAILABLE   AGE
ocp42-a26ek-w-a   1         1         1       1           91m
ocp42-a26ek-w-b   1         1         1       1           91m
ocp42-a26ek-w-c   1         1         1       1           91m

$ oc get machines -n openshift-machine-api
NAME                    STATE     TYPE            REGION        ZONE            AGE
ocp42-a26ek-w-a-xrgvb   RUNNING   n1-standard-4   us-central1   us-central1-a   91m
ocp42-a26ek-w-b-h72ss   RUNNING   n1-standard-4   us-central1   us-central1-b   91m
ocp42-a26ek-w-c-4x64c   RUNNING   n1-standard-4   us-central1   us-central1-c   91m
```

If `openshift_infra_count > 0` the infra nodes will host the router/ingress pods, all the monitoring infrastrucutre, and the image registry.
