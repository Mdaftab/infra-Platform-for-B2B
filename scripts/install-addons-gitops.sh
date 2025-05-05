#!/bin/bash
# GitOps-based Kubernetes add-ons installation using ArgoCD
# This script installs ArgoCD and configures it to manage cluster add-ons

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  GitOps-based Kubernetes Add-ons Installation              ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script installs ArgoCD and configures it to manage cluster add-ons"
echo

# Default values
DEFAULT_ADDONS_REPO="https://github.com/your-org/cluster-addons.git"
DEFAULT_ADDONS_PATH="manifests"
DEFAULT_ADDONS_BRANCH="main"

# Function to check prerequisites
check_prerequisites() {
  echo -e "${YELLOW}Checking prerequisites...${NC}"
  
  # Check if kubectl is installed
  if ! command -v kubectl >/dev/null 2>&1; then
    echo -e "${RED}Error: kubectl is not installed.${NC}"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
  fi
  
  # Check if helm is installed
  if ! command -v helm >/dev/null 2>&1; then
    echo -e "${RED}Error: helm is not installed.${NC}"
    echo "Please install Helm: https://helm.sh/docs/intro/install/"
    exit 1
  fi
  
  # Check if kubeconfig is configured
  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}Error: kubeconfig is not properly configured.${NC}"
    echo "Please make sure your kubeconfig is set up correctly."
    exit 1
  fi
  
  echo -e "${GREEN}All prerequisites are met.${NC}"
}

# Function to install ArgoCD
install_argocd() {
  echo -e "${YELLOW}Installing ArgoCD...${NC}"
  
  # Create argocd namespace
  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
  
  # Add ArgoCD Helm repository
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  
  # Install ArgoCD using Helm
  helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --version 5.46.7 \
    --set server.service.type=LoadBalancer \
    --set controller.metrics.enabled=true \
    --set server.metrics.enabled=true \
    --set global.logging.format=json \
    --wait
  
  # Wait for ArgoCD to be ready
  echo -e "${YELLOW}Waiting for ArgoCD to be ready...${NC}"
  kubectl wait --for=condition=available deployment -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s
  
  # Get the initial admin password
  ARGOCD_ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  
  # Get ArgoCD server URL
  ARGOCD_SERVER=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  
  echo -e "${GREEN}ArgoCD installed successfully.${NC}"
  echo -e "ArgoCD server: https://$ARGOCD_SERVER"
  echo -e "Initial admin username: admin"
  echo -e "Initial admin password: $ARGOCD_ADMIN_PASSWORD"
  echo -e "${YELLOW}Please change the admin password immediately after login.${NC}"
}

# Function to configure GitOps for add-ons
configure_gitops_addons() {
  echo -e "${YELLOW}Configuring GitOps for add-ons...${NC}"
  
  # Get Git repository for add-ons
  echo -e "${YELLOW}Enter Git repository URL for add-ons (or press Enter for default):${NC}"
  echo -e "Default: $DEFAULT_ADDONS_REPO"
  read -p "> " ADDONS_REPO
  ADDONS_REPO=${ADDONS_REPO:-$DEFAULT_ADDONS_REPO}
  
  # Get path to add-ons manifests
  echo -e "${YELLOW}Enter path to add-ons manifests in repository (or press Enter for default):${NC}"
  echo -e "Default: $DEFAULT_ADDONS_PATH"
  read -p "> " ADDONS_PATH
  ADDONS_PATH=${ADDONS_PATH:-$DEFAULT_ADDONS_PATH}
  
  # Get branch for add-ons
  echo -e "${YELLOW}Enter branch for add-ons (or press Enter for default):${NC}"
  echo -e "Default: $DEFAULT_ADDONS_BRANCH"
  read -p "> " ADDONS_BRANCH
  ADDONS_BRANCH=${ADDONS_BRANCH:-$DEFAULT_ADDONS_BRANCH}
  
  # Create ArgoCD Application for add-ons
  cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${ADDONS_REPO}
    targetRevision: ${ADDONS_BRANCH}
    path: ${ADDONS_PATH}
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
  
  echo -e "${GREEN}GitOps configuration for add-ons completed.${NC}"
}

# Function to create sample add-ons repository structure
create_sample_addons() {
  echo -e "${YELLOW}Would you like to create a sample add-ons repository structure? (y/n)${NC}"
  read -p "> " CREATE_SAMPLE
  
  if [[ "$CREATE_SAMPLE" == "y" || "$CREATE_SAMPLE" == "Y" ]]; then
    echo -e "${YELLOW}Creating sample add-ons repository structure...${NC}"
    
    # Create directory structure
    mkdir -p ./cluster-addons/apps
    mkdir -p ./cluster-addons/infrastructure
    
    # Create Application for NGINX Ingress Controller
    cat <<EOF > ./cluster-addons/infrastructure/nginx-ingress.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx
    chart: ingress-nginx
    targetRevision: 4.7.1
    helm:
      values: |
        controller:
          service:
            type: LoadBalancer
          metrics:
            enabled: true
          podAnnotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "10254"
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    # Create Application for cert-manager
    cat <<EOF > ./cluster-addons/infrastructure/cert-manager.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: v1.12.2
    helm:
      values: |
        installCRDs: true
        prometheus:
          enabled: true
        webhook:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    # Create ClusterIssuer for Let's Encrypt
    cat <<EOF > ./cluster-addons/infrastructure/letsencrypt-issuers.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

    # Create Application for Prometheus Stack
    cat <<EOF > ./cluster-addons/infrastructure/prometheus-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 48.3.1
    helm:
      values: |
        grafana:
          enabled: true
          adminPassword: admin123
        prometheus:
          prometheusSpec:
            retention: 15d
            serviceMonitorSelectorNilUsesHelmValues: false
            serviceMonitorSelector: {}
            serviceMonitorNamespaceSelector: {}
        alertmanager:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Create Application for External Secrets Operator
    cat <<EOF > ./cluster-addons/infrastructure/external-secrets.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    chart: external-secrets
    targetRevision: 0.9.5
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Create Application for Reloader
    cat <<EOF > ./cluster-addons/infrastructure/reloader.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: reloader
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://stakater.github.io/stakater-charts
    chart: reloader
    targetRevision: v1.0.40
  destination:
    server: https://kubernetes.default.svc
    namespace: reloader
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Create Application for Velero
    cat <<EOF > ./cluster-addons/infrastructure/velero.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: velero
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://vmware-tanzu.github.io/helm-charts
    chart: velero
    targetRevision: 4.1.3
    helm:
      values: |
        configuration:
          provider: gcp
          backupStorageLocation:
            bucket: your-backup-bucket
          volumeSnapshotLocation:
            config:
              project: your-project-id
              snapshotLocation: us-central1
  destination:
    server: https://kubernetes.default.svc
    namespace: velero
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

    # Create root Application to manage all infrastructure components
    cat <<EOF > ./cluster-addons/infrastructure.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${ADDONS_REPO}
    targetRevision: ${ADDONS_BRANCH}
    path: infrastructure
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

    echo -e "${GREEN}Sample add-ons repository structure created in ./cluster-addons/${NC}"
    echo -e "To use this structure, push it to your Git repository:"
    echo -e "git init ./cluster-addons"
    echo -e "cd ./cluster-addons"
    echo -e "git add ."
    echo -e "git commit -m \"Initial commit for cluster add-ons\""
    echo -e "git remote add origin ${ADDONS_REPO}"
    echo -e "git push -u origin ${ADDONS_BRANCH}"
  fi
}

# Main function
main() {
  check_prerequisites
  install_argocd
  configure_gitops_addons
  create_sample_addons
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║               GitOps Installation Complete                 ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${GREEN}✅ ArgoCD: Installed${NC}"
  echo -e "${GREEN}✅ Add-ons GitOps: Configured${NC}"
  
  echo
  echo -e "${BOLD}Next Steps:${NC}"
  echo -e "1. Access the ArgoCD UI at the URL shown above"
  echo -e "2. Log in with the provided credentials"
  echo -e "3. Change the default admin password"
  echo -e "4. Push your add-ons repository to Git"
  echo -e "5. ArgoCD will automatically deploy all add-ons"
  
  echo
  echo -e "${YELLOW}Note: Let's Encrypt certificates require a valid domain name.${NC}"
  echo -e "${YELLOW}Update the ClusterIssuer email before deploying to production.${NC}"
}

# Run the main function
main