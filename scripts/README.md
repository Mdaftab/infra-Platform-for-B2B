# Scripts Directory

This directory contains automation scripts for managing the Multi-Cluster Kubernetes Management Platform.

## Client Onboarding Scripts

### onboard-client.sh
**One-command client onboarding** - The main script that orchestrates the entire client onboarding process, including GCP project creation, GKE cluster provisioning, and GitHub setup.

### create-client-cluster-dedicated.sh
Creates a client-specific GKE cluster with a dedicated VPC in the client's GCP project for complete isolation.


### setup-github-client.sh
Sets up a GitHub project and repository for a client, including CI/CD configuration.

## Infrastructure Management Scripts

### setup.sh
Sets up the initial infrastructure for the platform, including GCP projects, service accounts, and permissions.

### cleanup.sh
Cleans up all resources created by the platform.

### install-cluster-addons.sh
Installs Kubernetes add-ons on a GKE cluster using direct Helm installations.

### install-addons-gitops.sh
Installs Kubernetes add-ons using the GitOps approach with ArgoCD.

## Usage

Most scripts are interactive and will prompt for necessary information. For example:

```bash
# Complete client onboarding process
./onboard-client.sh

# Install cluster add-ons using GitOps
./install-addons-gitops.sh
```

See the main README.md file for detailed instructions on each script's purpose and usage.