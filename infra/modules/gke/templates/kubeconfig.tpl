apiVersion: v1
kind: Config
clusters:
- name: ${cluster_name}
  cluster:
    server: https://${endpoint}
    certificate-authority-data: ${cluster_ca}
users:
- name: ${cluster_name}-admin
  user:
    client-certificate-data: ${client_cert}
    client-key-data: ${client_key}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${cluster_name}-admin
  name: ${cluster_name}
current-context: ${cluster_name}
