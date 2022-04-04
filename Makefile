update:
	git pull

install-docker:
	sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install docker-ce docker-ce-cli containerd.io
	sudo usermod -aG docker $$USER

install-go:
	curl -Lo ./go.tar.gz https://golang.org/dl/go1.16.6.linux-amd64.tar.gz
	sudo tar -C /usr/local -xzf go.tar.gz

install-kind:
	curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.12.0/kind-linux-amd64
	chmod +x ./kind
	sudo mv ./kind /usr/local/bin
	which kind

kubectl-install:
	curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	kubectl version --client

pre-cluster:
	sudo sysctl -w fs.inotify.max_queued_events=1048576
	sudo sysctl -w fs.inotify.max_user_watches=1048576
	sudo sysctl -w fs.inotify.max_user_instances=1048576

cluster-create:
	kind create cluster --config cluster/kind-config.yaml --name mon

kubectl-config:
	kind export kubeconfig --name mon

cluster-network:
	curl -L https://docs.projectcalico.org/manifests/calico.yaml -o cluster/calico.yaml
	sed -i 's/k8s,bgp"/k8s,bgp"\n            - name: IP_AUTODETECTION_METHOD\n              value: "interface=eth.*"/' cluster/calico.yaml
	kubectl apply -f cluster/calico.yaml

cluster-network-delete:
	kubectl delete -f cluster/calico.yaml

cluster-metrics:
	curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -o cluster/metrics.yaml
	sed -i '/^        - --metric-resolution.*/a\        - --kubelet-insecure-tls' cluster/metrics.yaml
	kubectl apply -f cluster/metrics.yaml

cluster-metrics-delete:
	kubectl delete -f cluster/metrics.yaml

cluster-helm-install:
	curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

install-nfs-server:
	sudo apt install nfs-kernel-server
	sudo vim /etc/exports
	sudo systemctl restart nfs-server.service

cluster-nfs-provider:
	helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
	helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=YOUR_NFS_SERVER_IP --set nfs.path=YOUR_NFS_SHARE_PATH

cluster-nfs-provider-delete:
	helm uninstall nfs-subdir-external-provisioner

cluster-monitoring-download:
	rm -rf prom
	git clone https://github.com/prometheus-operator/kube-prometheus.git prom
	sed -i '/^  ports.*/i\  type: NodePort' prom/manifests/alertmanager-service.yaml
	sed -i '/^  ports.*/i\  type: NodePort' prom/manifests/grafana-service.yaml
	sed -i '/^  ports.*/i\  type: NodePort' prom/manifests/prometheus-service.yaml
	sed -i '/^    targetPort: web.*/a\    nodePort: 30002' prom/manifests/alertmanager-service.yaml
	sed -i '/^    targetPort: http.*/a\    nodePort: 30000' prom/manifests/grafana-service.yaml
	sed -i '/^    targetPort: web.*/a\    nodePort: 30001' prom/manifests/prometheus-service.yaml
	sed -zi 's/      - emptyDir: {}\n        name: grafana-storage/      - name: grafana-storage\n        persistentVolumeClaim:\n          claimName: grafana-storage-pv-claim/' prom/manifests/grafana-deployment.yaml
	sed -zi 's/      - env: \[\]/      - env:\n        - name: GF_SECURITY_ADMIN_USER\n          valueFrom:\n            secretKeyRef:\n              name: grafana-credentials\n              key: user\n        - name: GF_SECURITY_ADMIN_PASSWORD\n          valueFrom:\n            secretKeyRef:\n              name: grafana-credentials\n              key: password/' prom/manifests/grafana-deployment.yaml

cluster-monitoring-setup:
	sudo rm -rf nfs/grafana
	mkdir -p nfs/grafana && chmod -R 777 nfs/grafana
	kubectl create -f prom/manifests/setup

cluster-monitoring:
	kubectl apply -k ./cluster
	kubectl apply -f prom/manifests

cluster-monitoring-delete:
	kubectl delete -f prom/manifests
	kubectl delete -k ./cluster

cluster-monitoring-uninstall:
	kubectl delete -f prom/manifests/setup

delete-cluster:
	kind delete cluster --name mon

up: pre-cluster cluster-create cluster-network

component: cluster-metrics cluster-nfs-provider cluster-monitoring-download cluster-monitoring-setup cluster-monitoring
