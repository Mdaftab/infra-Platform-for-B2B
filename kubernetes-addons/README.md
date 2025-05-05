# Kubernetes Add-ons

This directory contains configurations for Kubernetes add-ons that enhance the platform's functionality.

## Available Add-ons

### Core Add-ons

- **cert-manager**: Automates certificate management with Let's Encrypt integration
- **ingress-nginx**: Manages ingress traffic with NGINX controller
- **reloader**: Automatically restarts pods when configs change
- **secret-manager**: Integrates with GCP Secret Manager for external secrets

### Enhanced Add-ons (Added Recently)

- **prometheus-stack**: Comprehensive monitoring with Prometheus and Grafana
- **kyverno**: Kubernetes policy management and enforcement
- **velero**: Backup and recovery for Kubernetes resources
- **istio**: Service mesh for advanced networking and security
- **external-dns**: Automates DNS record management

## Installation

The add-ons can be installed using the interactive installation script:

```bash
./install.sh
```

This script will present options for installing:
- Essential add-ons only
- Monitoring add-ons only
- Security add-ons only
- Backup add-ons only
- Service mesh components only
- DNS management only
- All add-ons at once

## Configuration

Each add-on directory contains:
- `values.yaml`: Configuration values for the Helm chart
- Additional YAML files for custom resources related to the add-on

## GitOps Installation

For production environments, it's recommended to use the GitOps approach for add-on installation:

```bash
../scripts/install-addons-gitops.sh
```

This will install ArgoCD and configure it to manage all add-ons from a Git repository.