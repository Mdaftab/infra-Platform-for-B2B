# Crossplane Configuration

This directory contains Crossplane resources for dynamically provisioning and managing GKE clusters and other GCP resources.

## Directory Structure

- **bootstrap/**: Resources for setting up Crossplane in the infrastructure cluster
- **compositions/**: Crossplane compositions that define how to create GKE clusters
- **xresources/**: Cluster definitions and claims for different environments

## Compositions

### gke-cluster-dedicated.yaml
The composition that provisions GKE clusters with dedicated VPC networks for clients, providing complete tenant isolation in separate projects.

## XResources

### gke-cluster-definition.yaml
Defines the schema for GKE cluster resources, including networking, security, and node configuration options.

### dev-gke-cluster-claim.yaml, staging-gke-cluster-claim.yaml, prod-gke-cluster-claim.yaml
Claims for creating standard environment clusters (dev, staging, prod) using the dedicated VPC architecture.

### client-gke-cluster-dedicated-template.yaml
Template for creating client-specific clusters with dedicated VPC networks in their own projects.

## Usage

New client clusters can be created by:

1. Using the automated client onboarding script:
   ```bash
   ../scripts/onboard-client.sh
   ```

2. Using the client cluster creation script:
   ```bash
   ../scripts/create-client-cluster-dedicated.sh
   ```

3. Manually applying a cluster claim:
   ```bash
   kubectl --context=infracluster apply -f xresources/client-name-gke-cluster-claim.yaml
   ```

## How It Works

1. The Crossplane provider for GCP is installed in the infrastructure cluster
2. The composition defines how to create GKE clusters and related resources
3. Creating a claim triggers Crossplane to provision the resources according to the composition
4. The status of the resources can be monitored using Kubernetes tools