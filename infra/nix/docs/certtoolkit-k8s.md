# Using K8Nix certToolkit for the DuckNest Kubernetes Cluster

This guide captures a repeatable way to share TLS materials between the control plane (CP) that runs in EC2 and the on-prem worker nodes (WN) such as `laptop-firebat`. The workflow relies on [K8Nix](https://github.com/lux/K8Nix) and [agenix](https://github.com/ryantm/agenix) to generate, encrypt, and deploy certificates directly from this flake.

## 1. Extend the flake inputs

Add K8Nix and agenix as inputs and pass them to each host. The important pieces are:

```nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    k8nix.url = "github:lux/K8Nix";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, k8nix, agenix, ... }:
    let
      mkNixosConfig = hostname: system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = inputs;
          modules = [
            agenix.nixosModules.default
            k8nix.nixosModules.certToolkit
            ./hosts/${hostname}/configuration.nix
          ];
        };
```

Passing `specialArgs = inputs;` makes the flake inputs available to your host modules so you can reuse the same definition for all machines.【F:infra/nix/flake.nix†L1-L49】

## 2. Define reusable certificate policy

Create a module such as `infra/nix/modules/certs/cluster.nix` that owns the CA and every cert that a node needs:

```nix
{ config, lib, ... }:
{
  certToolkit = {
    dir = "./secrets/certs";
    userAgeIdentity = "$HOME/.ssh/id_ed25519";
    userAgeKeys = [
      "age1..." # developer workstations that may run nix run .#certs.recreate
    ];
    owningHostKey = ./ssh-host-keys/${config.networking.hostName}/ssh_host_ed25519_key.pub;

    defaults = {
      key = {
        algo = "rsa";
        size = 2048;
      };
      usages = [ "client auth" "server auth" ];
    };

    cas.cluster = {
      ca = {
        commonName = "ducksnest kubernetes ca";
        hosts = [];
        usages = [ "signing" "key encipherment" "client auth" "server auth" ];
        expiry = "87600h";
      };

      certDefaults.hosts = [ config.networking.hostName ];

      certs = {
        apiserver = {
          commonName = "kube-apiserver";
          hosts = [ "127.0.0.1" "ducksnest-controlplane" "firebat" ];
          usages = [ "server auth" "client auth" ];
        };
        controllerManager.commonName = "system:kube-controller-manager";
        scheduler.commonName = "system:kube-scheduler";
        kubelet.commonName = "system:node:${config.networking.hostName}";
        kubeProxy.commonName = "system:kube-proxy";
      };
    };
  };
}
```

This describes **one** CA (`cas.cluster.ca`) and the per-component certificates that each host should use. You can extend the `certs` set with etcd and service-account keys as needed.【F:infra/nix/modules/roles/control-plane.nix†L27-L72】【F:infra/nix/modules/roles/worker-node.nix†L26-L43】

## 3. Wire certificates into the control-plane role

The control-plane module already references files under `/var/lib/kubernetes/secrets`. Replace those paths with the ones that certToolkit provides so that the API server, controller manager, scheduler, and kubelet all use the shared CA:

```nix
  services.kubernetes = {
    easyCerts = false;
    apiserver = {
      clientCaFile = config.certToolkit.cas.cluster.ca.path;
      tlsCertFile = config.certToolkit.cas.cluster.certs.apiserver.path;
      tlsKeyFile = config.certToolkit.cas.cluster.certs.apiserver.keyPath;
      kubeletClientCertFile = config.certToolkit.cas.cluster.certs.kubelet.path;
      kubeletClientKeyFile = config.certToolkit.cas.cluster.certs.kubelet.keyPath;
      etcd.caFile = config.certToolkit.cas.cluster.ca.path;
      etcd.certFile = config.certToolkit.cas.cluster.certs.etcdClient.path;
      etcd.keyFile = config.certToolkit.cas.cluster.certs.etcdClient.keyPath;
    };

    controllerManager = {
      tlsCertFile = config.certToolkit.cas.cluster.certs.controllerManager.path;
      tlsKeyFile = config.certToolkit.cas.cluster.certs.controllerManager.keyPath;
      serviceAccountKeyFile = config.certToolkit.cas.cluster.certs.serviceAccount.keyPath;
    };
  };
```

Disable `easyCerts` so the module stops generating ephemeral self-signed material and consumes the reproducible certToolkit assets instead.【F:infra/nix/modules/roles/control-plane.nix†L24-L75】

## 4. Share kubelet certificates with worker nodes

Workers already expect a CA and kubelet certificate. Import the same `cluster.nix` module into each worker host configuration and use the certToolkit paths:

```nix
  imports = [
    ../../modules/roles/worker-node.nix
    ../../modules/certs/cluster.nix
  ];

  services.kubernetes.kubelet = {
    clientCaFile = config.certToolkit.cas.cluster.ca.path;
    tlsCertFile = config.certToolkit.cas.cluster.certs.kubelet.path;
    tlsKeyFile = config.certToolkit.cas.cluster.certs.kubelet.keyPath;
    kubeconfig = {
      server = "https://ducksnest-controlplane:6443";
      caFile = config.certToolkit.cas.cluster.ca.path;
      certFile = config.certToolkit.cas.cluster.certs.kubelet.path;
      keyFile = config.certToolkit.cas.cluster.certs.kubelet.keyPath;
    };
  };
```

When every machine imports the same certificate module, certToolkit automatically adds the encrypted key material to `age.secrets` so that the kubelet service can read it at boot.【F:infra/nix/modules/roles/worker-node.nix†L26-L55】

## 5. Generate and rotate certificates

1. Run `nix run .#certs.recreate` from the repository root whenever you add a host or rotate credentials.
2. Commit the generated public certificates (`*.crt`) and the age-encrypted keys (`*.key.age`) into `infra/nix/secrets/certs/...`. Only encrypted blobs are committed; clear-text private keys never leave `nix run`.
3. Distribute the host SSH public keys referenced by `owningHostKey` to keep agenix able to decrypt on the target machines.

Because everything lives in Git, new worker nodes such as `laptop-firebat` only need the flake plus their host SSH key: `nixos-rebuild switch --flake .#laptop-firebat` will fetch the encrypted key material, decrypt it locally through agenix, and hand it to kubelet. That allows CP ↔ WN trust to be bootstrapped without manual copying of certificates.【F:infra/nix/modules/roles/control-plane.nix†L24-L75】【F:infra/nix/modules/roles/worker-node.nix†L26-L55】

## 6. Optional: multi-document add-ons

If you plan to deploy cert-manager or other upstream YAML bundles, add `k8nix.nixosModules.kubernetesMultiYamlAddons` to the host modules and describe each bundle via `services.kubernetes.addonManager.multiYamlAddons`. The certToolkit-generated CA can then issue certificates for those controllers as well.

---

With these steps the CP and every WN (including `firebat`) converge on the same CA hierarchy without hand-crafted secrets. The agenix integration handles access control, and certToolkit makes key rotation idempotent.
