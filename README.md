# Qstars Kube-Hetzner Starter

This project configuration is an addition to the blogpost [Cheap Self Hosted Kubernetes on Hetzner Cloud](https://blog.qstars.nl/posts/cheap-self-hosted-kubernetes-on-hetzner-cloud/)

## Getting started

Follow these steps to deploy your Kubernetes cluster on Hetzner Cloud.

For more info and explanation around the `kube.tf` file, we recommend referencing the [kube.tf.example](https://github.com/mysticaltech/terraform-hcloud-kube-hetzner/blob/master/kube.tf.example) file in the [Kube-Hetzner repository](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner?tab=readme-ov-file).

### Prerequisites

First and foremost, you need to have a Hetzner Cloud account. You can sign up for free [here](https://hetzner.com/cloud/).

Then you'll need to have the following tools installed:

- [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) or [tofu](https://opentofu.org/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) cli
- [hcloud](https://github.com/hetznercloud/cli) - the Hetzner cli

The easiest way is to use [homebrew](https://brew.sh/) package manager to install them (available on macOS, Linux and Windows Linux Subsystem):

```bash
brew install terraform kubectl hcloud
```

### Setup Hetzner Cloud Project

1. **Create a project** in your [Hetzner Cloud Console](https://console.hetzner.cloud/), and go to **Security > API Tokens** of that project to grab the API key. It needs to be **Read & Write**. Take note of the key!

2. **Generate an SSH key pair** for your cluster (passphrase-less ed25519 recommended):

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/hetzner_kube -N ""
   ```

   Take note of the paths of your private and public keys.

3. **Set your Hetzner API token** as an environment variable:

   ```bash
   export HCLOUD_TOKEN="your_hcloud_api_token_here"
   ```

4. **Create a Hetzner CLI context** for your project:
   ```bash
   hcloud context create <project-name>
   ```

### Important configurations

Below are some configurations in `kube.tf` that you may want to change.

```terraform
cluster_name = "hcloud-cluster"
ssh_public_key  = file("~/.ssh/hetzner_kube.pub")
ssh_private_key = file("~/.ssh/hetzner_kube")
network_region = "eu-central"
load_balancer_type                  = "lb11"
load_balancer_location              = "fsn1"
load_balancer_algorithm_type        = "round_robin"
ingress_controller       = "traefik"
ingress_target_namespace = "traefik"


# Comment out this block if you don't want to backup your ETCD to S3 compatible storage
etcd_s3_backup = {
  etcd-s3-endpoint        = "xxxx.r2.cloudflarestorage.com"
  etcd-s3-access-key      = "<access-key>"
  etcd-s3-secret-key      = "<secret-key>"
  etcd-s3-bucket          = "k3s-etcd-snapshots"
  etcd-s3-region          = "<your-s3-bucket-region|usually required for aws>"
}

# Kubernetes Reboot Daemon options
kured_options = {
  "reboot-days" : "sat,su",
  "start-time" : "3am",
  "end-time" : "8am",
  "time-zone" : "Local",
  "lock-ttl" : "30m",
}

firewall_kube_api_source = null
firewall_ssh_source = ["1.2.3.4/32"]
disable_selinux = false
block_icmp_ping_in = false
enable_cert_manager = true
enable_wireguard = true
dns_servers = [
  "1.1.1.1",
  "8.8.8.8",
  "2606:4700:4700::1111",
]
use_control_plane_lb = true

```

### Deploy the Cluster

Now you're ready to deploy your cluster:

1. **Initialize Terraform** (downloads required providers):

   ```bash
   terraform init --upgrade
   ```

2. **Validate your configuration**:

   ```bash
   terraform validate
   ```

3. **Review the deployment plan**:

   ```bash
   terraform plan
   ```

4. **Deploy the cluster**:

   ```bash
   terraform apply
   ```

   Or to auto-approve:

   ```bash
   terraform apply -auto-approve
   ```

5. **Get the Kubeconfig**:

   ```
   terraform output --raw kubeconfig > cluster_kubeconfig.yaml
   ```

The deployment will take around 10 minutes to complete. Once finished, you should see a green output confirming a successful deployment.
