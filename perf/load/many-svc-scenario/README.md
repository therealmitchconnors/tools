To reproduce my scalability tests, first create a cluster named 'testcluster' using the following commands (for tests not involving Azure CNI w/ cilium, omit the --network-dataplane parameter):

```
az aks create -g mitch-delete-oct24 -n testcluster --tier standard --network-plugin azure --network-plugin-mode overlay --pod-cidrs 10.128.0.0/10 --node-vm-size Standard_D8ds_v5 
az aks nodepool add -g mitch-delete-oct24 --cluster-name testcluster -n clientpool -s "Standard_D32ds_v5" --labels size=large --node-taints client=true:NoSchedule -c 100
az aks nodepool add -g mitch-delete-oct24 --cluster-name testcluster -n serverpool -s "Standard_D8ds_v5" --labels size=small,group=1 -c 900
```
Note: this requires 11,200 cores of dsv5 quota in your default region and subscription.

Next, optionally install Istio or Cilium, depending on the configuraiton you would like to test.

```
helm install cilium cilium/cilium --version 1.16.1 \
  --namespace kube-system \
  --set aksbyocni.enabled=true \
  --set nodeinit.enabled=true \
  --set encryption.enabled=true \
  --set encryption.type=wireguard
  --set l7Proxy=true
  --set ciliumEndpointSlice.enabled=true
  ```
  Or follow Istio install instructions at https://istio.io/latest/docs/ambient/install/helm/, using istiod-values.yaml.

  Deploy the test workloads using ` helm template . -n default --set serviceCount=500 --set dataplaneMode=none --set replicas=100 --set scalerange=30 | kubectl apply -f -`
  Optionally, set istioL4, istioL7, ciliumL4, and ciliumL7 values to true for particular test configurations.  If cilium is installed, this command might cause the cluster to enter a metastable failure state.  For this reason, it is recommended to break the command into smaller units using the start env var, which allows you to deploy, for instance, namespaces 1-50, then wait, then 51-100, then wait.  Distributing the deployment over ~8 hours should be sufficient to keep cilium from crashing the cluster.

  Once all test services are deployed and available, and the cilium control plane has stabilized, start the config churner with `kubectl  scale deployment deployment-scaler --replicas 1`

  The test will be run from the fortio-commander pod.  To get a shell on the pod, run `kubectl exec -n default deployment/fortio-commander -- bash`.  Within the pod, run the following commands to place the test results in results.json:

  ```
  apk add jq
  ../commander-scripts/build-clients.sh
  mkdir out
  fortio-commander -c clients.json -o out/ -d ../commander-scripts/test.json
  fortio-commander aggregate out/ | jq. > results.json
  ```
  This will run a 10 minute test targeting all services with max QPS.  To view the istio and cilium resource utilization, run `port-forward -n default deployment/prometheus 9090`, and then visit http://localhost:9090/graph?g0.expr=sum%20by%20(container)%20(container_memory_working_set_bytes%7Bcontainer!%3D%22%22%2Cpod%3D~%22cilium.*%22%7D)&g0.tab=0&g0.display_mode=stacked&g0.show_exemplars=0&g0.range_input=1h&g1.expr=%20sum%20by%20(container)%20(rate%20(container_cpu_usage_seconds_total%7Bcontainer!%3D%22%22%2Cpod%3D~%22cilium.*%22%7D%5B1m%5D))&g1.tab=0&g1.display_mode=stacked&g1.show_exemplars=0&g1.range_input=1h&g2.expr=sum%20by%20(image)%20(container_memory_working_set_bytes%7Bcontainer%3D%22istio-proxy%22%2C%20image!%3D%22%22%7D%20or%20container_memory_working_set_bytes%7Bnamespace%3D%22istio-system%22%2C%20image!%3D%22%22%7D)&g2.tab=0&g2.display_mode=stacked&g2.show_exemplars=0&g2.range_input=1h29m21s657ms&g3.expr=sum%20by%20(image)%20(rate%20(container_cpu_usage_seconds_total%7Bcontainer!%3D%22%22%2C%20namespace%3D%22istio-system%22%7D%5B1m%5D)%20or%20rate(container_cpu_usage_seconds_total%7Bcontainer%3D%22istio-proxy%22%2C%20image!%3D%22%22%7D%5B1m%5D))&g3.tab=0&g3.display_mode=stacked&g3.show_exemplars=0&g3.range_input=1h6m38s425ms&g4.expr=sum%20by%20(container)%20(rate%20(container_cpu_usage_seconds_total%7Bcontainer!%3D%22%22%2Ckubernetes_io_hostname%3D~%22aks-clientpool.*%22%7D%5B1m%5D))&g4.tab=0&g4.display_mode=stacked&g4.show_exemplars=0&g4.range_input=1h&g5.expr=sum%20by%20(k8s_app)%20(cilium_bpf_maps_virtual_memory_max_bytes)&g5.tab=0&g5.display_mode=stacked&g5.show_exemplars=0&g5.range_input=1h
