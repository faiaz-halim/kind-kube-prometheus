> Important: If any commands require sudo privileges and your user don't have passwordless sudo enabled, copy the commands from makefile and run in your favorite shell.

> Important: This was setup as proof-of-concept of a production system. For local development purpose please use 1 control-plane and 2 worker node configuration and RAM usage will be under control (assuming the system has atleast 5gb ram available).

> Important: Set following if multi master many worker nodes fail to join,

```
sudo sysctl -w fs.inotify.max_queued_events=1048576
sudo sysctl -w fs.inotify.max_user_watches=1048576
sudo sysctl -w fs.inotify.max_user_instances=1048576
```

## Install Docker

Install Docker with,

```
make install-docker
```

## Install GO (optional, only necessary if you want to build kind node images)

Install go with,

```
make install-go
```

Set path in bashrc or zshrc,

```
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
```

## Install KinD

Install KinD with,

```
make install-kind
```

## Create KinD cluster

Create KinD cluster with,

```
make cluster-create
```

> Important: KinD cluster should not be exposed publicly. This settings are not suitable for any production environment. Please be aware of security concerns before exposing local KinD cluster publicly. 

```
networking:
  disableDefaultCNI: true
  apiServerAddress: "YOUR_IP"
  apiServerPort: YOUR_PORT
```

## Delete KinD cluster

Destroy KinD cluster with, (NFS storage contents won't be deleted)

```
delete-cluster
```

## Regenerate kubeconfig

With every system reboot the exposed api server endpoint and certificate in kubeconfig will change. Regenerate kubeconfig of current cluster for kubectl with, 

> This will not work for HA settings. The haproxy loadbalancer container don't get certificate update this way. Copying api address ip and certificate over to loadbalancer docker container process is still ```TODO```. For HA KinD cluster you have to destroy cluster every time before shutdown and recreate it later.

```
make kubectl-config
```

### Common Troubleshooting:

If cluster creation process is taking a long time at "Starting control-plane" step and exits with error similar to,

```
The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.
```

It means you probably have some physical or virtual network settings that KinD is not working with. For example kvm bridge network requires you to use a bridge network and bridge slave network based on the physical network interface. KinD does not support this scenario. After reverting to default network connection based on physical network device it completed the setup process.

Kubernetes version 1.23.4 node images were used to setup this cluster. Provide your customized name in makefile commands for create and delete cluster section. Clusters with same name can't exist. 

If you need to use different version kubernetes node image, be aware of kubernetes feature gates and their default value according to version. If any feature gate default value is true, KinD config doesn't support setting it true again using cluster config yaml files. For example ```TTLAfterFinished``` is ```true``` by default in 1.21 but false in previous versions. So specifying it as ```true``` again for 1.21 cluster version in ```featureGates``` section in ```cluster/kind-config.yaml``` won't work.

If docker restarts for any reason please look if loadbalancer container is autostarted. Otherwise you can't regenerate kubeconfig for kubectl in case it is unable to connect to kind cluster.

## Create cluster network

Create cluster network using CNI manifests,

```
make cluster-network
```

Here Calico manifest is used with BGP peering and pod CIDR ```192.168.0.0/16``` settings. For updated version or any change in manifest, download from,

```
curl https://docs.projectcalico.org/manifests/calico.yaml -O
```

All Calico pods must be running before installing other components in cluster. If you want to use different CNI, download the manifest and replace filename in makefile.

Run following command to install calico cni with bgp peering,

```
make cluster-network
```

If pod description shows error like ```liveness and readiness probes failed``` make sure any pod ip is not overlapping your LAN network ip range.

## Delete cluster network

Delete Calico CNI with,

```
make cluster-network-delete
```

## Create metric server

Install metric server with,

```
make cluster-metrics
```

## Delete metric server

Delete metric server with,

```
make cluster-metrics-delete
```

## Install NFS server

If NFS server isn't installed run command to install and configure NFS location,

```
make install-nfs-server
```

Add your location with this format in ```/etc/exports``` file,

```
YOUR_NFS_PATH *(rw,sync,no_root_squash,insecure,no_subtree_check)
```

Restart NFS server to apply changes,

```
sudo systemctl restart nfs-server.service
```

## Create NFS storage class

Install Helm with,

```
make cluster-helm-install
```

```k8s-sigs.io/nfs-subdir-external-provisioner``` storage provisioner is used to better simulate production scenario where usually log, metric, data storage are centralized and retained even if containers get destroyed and rescheduled. 

Before installing nfs storage provisioner rename ```grafana-pv.yaml.template``` to ```grafana-pv.yaml``` and update following values with your own in ```Makefile``` and ```grafana-pv.yaml```, (make sure folder write permission is present)

```
YOUR_NFS_SHARE_PATH
YOUR_NFS_SERVER_IP
```

Install nfs storage class with,

```
make cluster-nfs-provider
```

## Delete NFS storage class

Delete nfs storage class with,

```
make cluster-nfs-provider-delete
```

## Apply Prometheus-Grafana monitoring system

Prometheus, grafana, alertmanager and custom CRDs associated with them are exactly taken as is from ```kube-prometheus``` project (```https://github.com/prometheus-operator/kube-prometheus```). Please note the kubernetes compatibility matrix and download appropriate release for your version. This system uses release-0.10. 

Download kube-prometheus repository and perform necessary updates,

```
make cluster-monitoring-download
```

Apply setup prerequisites with,

```
make cluster-monitoring-setup
```

Apply manifests with,

```
make cluster-monitoring
```

## Delete Prometheus-Grafana monitoring system

Delete prometheus, grafana, alertmanager and custom CRDs with,

```
make cluster-monitoring-delete
make cluster-monitoring-uninstall
```
