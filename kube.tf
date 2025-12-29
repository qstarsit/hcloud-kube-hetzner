locals {
  # You have the choice of setting your Hetzner API token here or define the TF_VAR_hcloud_token env
  # within your shell, such as: export TF_VAR_hcloud_token=xxxxxxxxxxx
  # If you choose to define it in the shell, this can be left as is.

  # Your Hetzner token can be found in your Project > Security > API Token (Read & Write is required).
  hcloud_token = "xxxxxxxxxxx"
}

module "kube-hetzner" {
  providers = {
    hcloud = hcloud
  }
  hcloud_token    = var.hcloud_token != "" ? var.hcloud_token : local.hcloud_token
  source          = "kube-hetzner/kube-hetzner/hcloud"
  ssh_public_key  = file("~/.ssh/id_ed25519.pub")
  ssh_private_key = file("~/.ssh/id_ed25519")

  # You can add additional SSH public Keys to grant other team members root access to your cluster nodes.
  # ssh_additional_public_keys = []

  cluster_name                  = "hcloud-cluster"
  use_cluster_name_in_node_name = false

  # * For Hetzner locations see https://docs.hetzner.com/general/others/data-centers-and-connection/
  network_region = "eu-central" # change to `us-east` if location is ash
  control_plane_nodepools = [
    {
      name            = "control-plane-fsn1",
      server_type     = "cx22",
      location        = "fsn1",
      labels          = [],
      taints          = [],
      count           = 1
      placement_group = "default"
      backups         = true

      # disable_ipv4 = true
      # disable_ipv6 = true
    },
    {
      name            = "control-plane-nbg1",
      server_type     = "cx22",
      location        = "nbg1",
      labels          = [],
      taints          = [],
      count           = 1
      placement_group = "default"
      backups         = true

      # disable_ipv4 = true
      # disable_ipv6 = true
    },
    {
      name            = "control-plane-hel1",
      server_type     = "cx22",
      location        = "hel1",
      labels          = [],
      taints          = [],
      count           = 1
      placement_group = "default"
      backups         = true
      # disable_ipv4 = true
      # disable_ipv6 = true
    }
  ]

  agent_nodepools = [
    {
      name            = "agent-small",
      server_type     = "cx22",
      location        = "fsn1",
      labels          = [],
      taints          = [],
      count           = 1
      placement_group = "default"
      backups         = true
    },
    {
      name            = "agent-large",
      server_type     = "cx32",
      location        = "nbg1",
      labels          = [],
      taints          = [],
      count           = 1
      placement_group = "default"
      backups         = true
    }
  ]
  control_planes_custom_config = {
    etcd-expose-metrics = true,
  }

  agent_nodes_custom_config = {
    kube-proxy-arg = "metrics-bind-address=0.0.0.0",
  }

  # Enable etcd snapshot backups to S3 storage.
  # Just provide a map with the needed settings (according to your S3 storage provider) and backups to S3 will
  # be enabled (with the default settings for etcd snapshots).
  # Cloudflare's R2 offers 10GB, 10 million reads and 1 million writes per month for free.
  # For proper context, have a look at https://docs.k3s.io/datastore/backup-restore.
  # You also can use additional parameters from https://docs.k3s.io/cli/etcd-snapshot, such as `etc-s3-folder`
  etcd_s3_backup = {
    etcd-s3-endpoint   = "xxxx.r2.cloudflarestorage.com"
    etcd-s3-access-key = "<access-key>"
    etcd-s3-secret-key = "<secret-key>"
    etcd-s3-bucket     = "k3s-etcd-snapshots"
    etcd-s3-region     = "<your-s3-bucket-region|usually required for aws>"
  }

  # FYI, Hetzner says "Traffic between cloud servers inside a Network is private and isolated, but not automatically encrypted." https://docs.hetzner.com/cloud/networks/faq/#is-traffic-inside-hetzner-cloud-networks-encrypted
  # Just note, that if Cilium with cilium_values, the responsibility of enabling of disabling Wireguard falls on you.
  enable_wireguard = true

  # * LB location and type, the latter will depend on how much load you want it to handle, see https://www.hetzner.com/cloud/load-balancer
  load_balancer_type                  = "lb11"
  load_balancer_location              = "fsn1"
  load_balancer_algorithm_type        = "round_robin"
  load_balancer_health_check_interval = "5s"
  load_balancer_health_check_timeout  = "3s"
  load_balancer_health_check_retries  = 3

  # You can refine a base domain name to be use in this form of nodename.base_domain for setting the reverse dns inside Hetzner
  # base_domain = "mycluster.example.com"

  # Enable delete protection on compatible resources to prevent accidental deletion from the Hetzner Cloud Console.
  # This does not protect deletion from Terraform itself.
  enable_delete_protection = {
    floating_ip   = true
    load_balancer = true
    volume        = true
  }

  # To enable Hetzner Storage Box support, you can enable csi-driver-smb, default is "false".
  enable_csi_driver_smb = true
  hetzner_ccm_use_helm  = true

  # If you want to enable the Nginx (https://kubernetes.github.io/ingress-nginx/) or HAProxy ingress controller instead of Traefik, you can set this to "nginx" or "haproxy".
  ingress_controller       = "traefik"
  ingress_target_namespace = "traefik"

  # Use the klipperLB (similar to metalLB), instead of the default Hetzner one, that has an advantage of dropping the cost of the setup.
  # Automatically "true" in the case of single node cluster.
  # Please note that because the klipperLB points to all nodes, we automatically allow scheduling on the control plane when it is active.
  # enable_klipper_metal_lb = "true"

  enable_local_storage     = true
  system_upgrade_use_drain = true

  # During k3s via system-upgrade-manager pods are evicted by default.
  # On small clusters this can lead to hanging upgrades and indefinitely unschedulable nodes,
  # in that case, set this to false to immediately delete pods before upgrading.
  # NOTE: Turning this flag off might lead to downtimes of services (which may be acceptable for your use case)
  # NOTE: This flag takes effect only when system_upgrade_use_drain is set to true.
  # system_upgrade_enable_eviction = false

  # The default is "true" (in HA setup it works wonderfully well, with automatic roll-back to the previous snapshot in case of an issue).
  # IMPORTANT! For non-HA clusters i.e. when the number of control-plane nodes is < 3, you have to turn it off.
  # automatically_upgrade_os = false

  kured_options = {
    "reboot-days" : "sat,su",
    "start-time" : "3am",
    "end-time" : "8am",
    "time-zone" : "Local",
    "lock-ttl" : "30m",
  }

  # If you want to allow all outbound traffic you can set this to "false". Default is "true".
  # restrict_outbound_traffic = false

  # Allow access to the Kube API from the specified networks. The default is ["0.0.0.0/0", "::/0"].
  # Allowed values: null (disable Kube API rule entirely) or a list of allowed networks with CIDR notation.
  # For maximum security, it's best to disable it completely by setting it to null. However, in that case, to get access to the kube api,
  # you would have to connect to any control plane node via SSH, as you can run kubectl from within these.
  # Please be advised that this setting has no effect on the load balancer when the use_control_plane_lb variable is set to true. This is
  # because firewall rules cannot be applied to load balancers yet.
  firewall_kube_api_source = null

  # Allow SSH access from the specified networks. Default: ["0.0.0.0/0", "::/0"]
  # Allowed values: null (disable SSH rule entirely) or a list of allowed networks with CIDR notation.
  # Ideally you would set your IP there. And if it changes after cluster deploy, you can always update this variable and apply again.
  firewall_ssh_source = ["1.2.3.4/32"]

  # By default, SELinux is enabled in enforcing mode on all nodes. For container-specific SELinux issues,
  # consider using the pre-installed 'udica' tool to create custom, targeted SELinux policies instead of
  # disabling SELinux globally. See the "Fix SELinux issues with udica" example in the README for details.
  disable_selinux = false

  # Adding extra firewall rules, like opening a port
  # More info on the format here https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/firewall
  # extra_firewall_rules = [
  #   {
  #     description = "For Postgres"
  #     direction       = "in"
  #     protocol        = "tcp"
  #     port            = "5432"
  #     source_ips      = ["0.0.0.0/0", "::/0"]
  #     destination_ips = [] # Won't be used for this rule
  #   },
  #   {
  #     description = "To Allow ArgoCD access to resources via SSH"
  #     direction       = "out"
  #     protocol        = "tcp"
  #     port            = "22"
  #     source_ips      = [] # Won't be used for this rule
  #     destination_ips = ["0.0.0.0/0", "::/0"]
  #   }
  # ]
  cni_plugin            = "cilium"
  cilium_hubble_enabled = true
  cilium_hubble_metrics_enabled = [
    "policy:sourceContext=app|workload-name|pod|reserved-identity;destinationContext=app|workload-name|pod|dns|reserved-identity;labelsContext=source_namespace,destination_namespace"
  ]
  block_icmp_ping_in  = false
  enable_cert_manager = true

  # IP Addresses to use for the DNS Servers, the defaults are the ones provided by Hetzner https://docs.hetzner.com/dns-console/dns/general/recursive-name-servers/.
  # The number of different DNS servers is limited to 3 by Kubernetes itself.
  # It's always a good idea to have at least 1 IPv4 and 1 IPv6 DNS server for robustness.
  dns_servers = [
    "1.1.1.1",
    "8.8.8.8",
    "2606:4700:4700::1111",
  ]

  use_control_plane_lb  = true
  control_plane_lb_type = "lb11"

  # Let's say you are not using the control plane LB solution above, and still want to have one hostname point to all your control-plane nodes.
  # You could create multiple A records of to let's say cp.cluster.my.org pointing to all of your control-plane nodes ips.
  # In which case, you need to define that hostname in the k3s TLS-SANs config to allow connection through it. It can be hostnames or IP addresses.
  # additional_tls_sans = ["cp.cluster.my.org"]

  # If you create a hostname with multiple A records pointing to all of your
  # control-plane nodes ips, you may want to use that hostname in the generated
  # kubeconfig.
  # kubeconfig_server_address = "cp.cluster.my.org"

  # lb_hostname Configuration:
  #
  # Purpose:
  # The lb_hostname setting optimizes communication between services within the Kubernetes cluster
  # when they use domain names instead of direct service names. By associating a domain name directly
  # with the Hetzner Load Balancer, this setting can help reduce potential communication delays.
  #
  # Scenario:
  # If Service B communicates with Service A using a domain (e.g., `a.mycluster.domain.com`) that points
  # to an external Load Balancer, there can be a slowdown in communication.
  #
  # Guidance:
  # - If your internal services use domain names pointing to an external LB, set lb_hostname to a domain
  #   like `mycluster.domain.com`.
  # - Create an A record pointing `mycluster.domain.com` to your LB's IP.
  # - Create a CNAME record for `a.mycluster.domain.com` (or xyz.com) pointing to `mycluster.domain.com`.
  #
  # Technical Note:
  # This setting sets the `load-balancer.hetzner.cloud/hostname` in the Hetzner LB definition, suitable for
  # HAProxy, Nginx and Traefik ingress controllers.
  #
  # Recommendation:
  # This setting is optional. If services communicate using direct service names, you can leave this unset.
  # For inter-namespace communication, use `.service_name` as per Kubernetes norms.
  #
  # Example:
  # lb_hostname = "mycluster.domain.com"

  create_kubeconfig = false
  export_values     = true
}

provider "hcloud" {
  token = var.hcloud_token != "" ? var.hcloud_token : local.hcloud_token
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.51.0"
    }
  }
}

output "kubeconfig" {
  value     = module.kube-hetzner.kubeconfig
  sensitive = true
}

variable "hcloud_token" {
  sensitive = true
  default   = ""
}
