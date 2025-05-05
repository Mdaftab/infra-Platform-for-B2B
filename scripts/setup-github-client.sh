#!/bin/bash
# Script to set up GitHub project and repository for a client
# This integrates with the client cluster creation process

set -e

# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration variables
GH_ORG=${1:-"infrasearch"}
CLIENT_NAME=${2:-""}
CLIENT_DESCRIPTION=${3:-"Client environment for deploying InfraSearch"}
TEMPLATE_REPO=${4:-"infrasearch/client-template"}
GH_TOKEN=${GH_TOKEN:-""}

# Banner
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  GitHub Client Project Setup                               ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "This script sets up a GitHub project and repository for client deployment."
echo

# Function to check prerequisites
check_prerequisites() {
  echo -e "${YELLOW}Checking prerequisites...${NC}"
  
  # Check if gh CLI is installed
  if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Please install GitHub CLI: https://cli.github.com/manual/installation"
    exit 1
  fi
  
  # Check if GH_TOKEN is set or gh is authenticated
  if [ -z "$GH_TOKEN" ]; then
    if ! gh auth status >/dev/null 2>&1; then
      echo -e "${RED}Error: Not authenticated with GitHub.${NC}"
      echo "Please run 'gh auth login' or set GH_TOKEN environment variable."
      exit 1
    fi
  else
    # Set GH_TOKEN for authentication
    echo -e "${YELLOW}Using provided GitHub token for authentication.${NC}"
    export GITHUB_TOKEN=$GH_TOKEN
  fi
  
  # Check for required arguments
  if [ -z "$CLIENT_NAME" ]; then
    echo -e "${RED}Error: Client name is required.${NC}"
    echo "Usage: $0 [GITHUB_ORG] CLIENT_NAME [DESCRIPTION] [TEMPLATE_REPO]"
    exit 1
  fi
  
  echo -e "${GREEN}All prerequisites are met.${NC}"
  echo "Using the following configuration:"
  echo "- GitHub Organization: $GH_ORG"
  echo "- Client Name: $CLIENT_NAME"
  echo "- Description: $CLIENT_DESCRIPTION"
  echo "- Template Repository: $TEMPLATE_REPO"
  echo
}

# Function to create GitHub project for client
create_github_project() {
  echo -e "${YELLOW}Creating GitHub project for client: $CLIENT_NAME...${NC}"
  
  # Check if project already exists
  if gh project list --owner $GH_ORG | grep -q "$CLIENT_NAME"; then
    echo -e "${YELLOW}Project already exists for $CLIENT_NAME. Skipping creation.${NC}"
    PROJECT_URL=$(gh project list --owner $GH_ORG --format json | jq -r ".[] | select(.title == \"$CLIENT_NAME\") | .url")
    echo -e "Project URL: $PROJECT_URL"
    return
  fi
  
  # Create new project
  PROJECT_URL=$(gh project create "$CLIENT_NAME" \
    --owner $GH_ORG \
    --description "$CLIENT_DESCRIPTION" \
    --format json | jq -r '.url')
  
  echo -e "${GREEN}GitHub project created successfully.${NC}"
  echo -e "Project URL: $PROJECT_URL"
}

# Function to create GitHub repository for client
create_github_repository() {
  echo -e "${YELLOW}Creating GitHub repository for client: $CLIENT_NAME...${NC}"
  
  # Check if repository already exists
  if gh repo list $GH_ORG | grep -q "$GH_ORG/$CLIENT_NAME"; then
    echo -e "${YELLOW}Repository already exists: $GH_ORG/$CLIENT_NAME. Skipping creation.${NC}"
    REPO_URL="https://github.com/$GH_ORG/$CLIENT_NAME"
    return
  fi
  
  # Create repository from template
  if [ -n "$TEMPLATE_REPO" ]; then
    if gh repo list | grep -q "$TEMPLATE_REPO"; then
      gh repo create "$GH_ORG/$CLIENT_NAME" \
        --template="$TEMPLATE_REPO" \
        --description "$CLIENT_DESCRIPTION" \
        --private
    else
      echo -e "${YELLOW}Template repository not found. Creating empty repository.${NC}"
      gh repo create "$GH_ORG/$CLIENT_NAME" \
        --description "$CLIENT_DESCRIPTION" \
        --private
    fi
  else
    # Create empty repository
    gh repo create "$GH_ORG/$CLIENT_NAME" \
      --description "$CLIENT_DESCRIPTION" \
      --private
  fi
  
  REPO_URL="https://github.com/$GH_ORG/$CLIENT_NAME"
  echo -e "${GREEN}GitHub repository created successfully.${NC}"
  echo -e "Repository URL: $REPO_URL"
}

# Function to setup GitHub Actions secrets with cluster credentials
setup_repository_secrets() {
  echo -e "${YELLOW}Setting up GitHub Actions secrets for cluster access...${NC}"
  
  # Get the GKE credentials for this client
  echo -e "${YELLOW}Getting cluster credentials for $CLIENT_NAME-gke-cluster...${NC}"
  
  # Get the current context (save it to restore later)
  CURRENT_CONTEXT=$(kubectl config current-context)
  
  # Check if credentials file exists
  KUBECONFIG_PATH="/tmp/$CLIENT_NAME-kubeconfig"
  rm -f $KUBECONFIG_PATH
  
  echo -e "${YELLOW}Do you want to get GKE credentials now? (y/n)${NC}"
  read -p "> " GET_CREDS
  
  if [[ "$GET_CREDS" == "y" || "$GET_CREDS" == "Y" ]]; then
    echo -e "${YELLOW}Please enter the client project ID:${NC}"
    read -p "> " CLIENT_PROJECT_ID
    
    # Get the credentials
    gcloud container clusters get-credentials "$CLIENT_NAME-gke-cluster" \
      --project="$CLIENT_PROJECT_ID" \
      --region="us-central1" \
      --format="config" > $KUBECONFIG_PATH
    
    if [ ! -f $KUBECONFIG_PATH ]; then
      echo -e "${RED}Error: Failed to get cluster credentials.${NC}"
      echo "Please make sure the cluster exists and you have the necessary permissions."
      kubectl config use-context "$CURRENT_CONTEXT"
      exit 1
    fi
    
    # Base64 encode the kubeconfig
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      KUBECONFIG_B64=$(base64 -i $KUBECONFIG_PATH)
    else
      # Linux
      KUBECONFIG_B64=$(base64 -w 0 $KUBECONFIG_PATH)
    fi
    
    # Set the secrets
    echo -e "${YELLOW}Setting GitHub Actions secrets...${NC}"
    gh secret set GKE_PROJECT --repo="$GH_ORG/$CLIENT_NAME" --body="$CLIENT_PROJECT_ID"
    gh secret set GKE_CLUSTER_NAME --repo="$GH_ORG/$CLIENT_NAME" --body="$CLIENT_NAME-gke-cluster"
    gh secret set GKE_REGION --repo="$GH_ORG/$CLIENT_NAME" --body="us-central1"
    gh secret set KUBECONFIG --repo="$GH_ORG/$CLIENT_NAME" --body="$KUBECONFIG_B64"
    
    # Clean up
    rm -f $KUBECONFIG_PATH
    kubectl config use-context "$CURRENT_CONTEXT"
    
    echo -e "${GREEN}GitHub Actions secrets set successfully.${NC}"
  else
    echo -e "${YELLOW}Skipping credential setup. You'll need to set up the following secrets manually:${NC}"
    echo "- GKE_PROJECT: The client's GCP project ID"
    echo "- GKE_CLUSTER_NAME: $CLIENT_NAME-gke-cluster"
    echo "- GKE_REGION: us-central1"
    echo "- KUBECONFIG: Base64-encoded kubeconfig for the cluster"
  fi
}

# Function to setup client CI/CD pipeline
setup_cicd_workflow() {
  echo -e "${YELLOW}Setting up CI/CD workflow for client repository...${NC}"
  
  # Clone the repository
  TEMP_DIR=$(mktemp -d)
  
  echo -e "${YELLOW}Cloning repository to setup CI/CD workflow...${NC}"
  gh repo clone "$GH_ORG/$CLIENT_NAME" "$TEMP_DIR"
  
  # Create GitHub workflows directory if it doesn't exist
  mkdir -p "$TEMP_DIR/.github/workflows"
  
  # Create CI/CD workflow file
  cat > "$TEMP_DIR/.github/workflows/deploy.yaml" << EOF
name: Deploy to Client GKE Cluster

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  PROJECT_ID: \${{ secrets.GKE_PROJECT }}
  GKE_CLUSTER: \${{ secrets.GKE_CLUSTER_NAME }}
  GKE_REGION: \${{ secrets.GKE_REGION }}
  DEPLOYMENT_NAME: $CLIENT_NAME-app
  IMAGE: $CLIENT_NAME-app

jobs:
  build-and-deploy:
    name: Build and Deploy
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v3
      
    - name: Set up Google Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
      with:
        project_id: \${{ secrets.GKE_PROJECT }}
        
    - name: Authenticate with Google Cloud
      uses: google-github-actions/auth@v1
      with:
        credentials_json: \${{ secrets.GCP_CREDENTIALS }}
        
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
        
    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: gcr.io/\${{ secrets.GKE_PROJECT }}/$CLIENT_NAME-app:latest,gcr.io/\${{ secrets.GKE_PROJECT }}/$CLIENT_NAME-app:\${{ github.sha }}
        
    - name: Set up kubectl
      uses: azure/setup-kubectl@v3
      
    - name: Deploy to GKE
      run: |
        echo "\${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig.yaml
        export KUBECONFIG=./kubeconfig.yaml
        
        # Update the image in the deployment
        kubectl set image deployment/\${DEPLOYMENT_NAME} \${DEPLOYMENT_NAME}=gcr.io/\${PROJECT_ID}/\${IMAGE}:\${{ github.sha }} --namespace=default
        
        # Verify the deployment
        kubectl rollout status deployment/\${DEPLOYMENT_NAME} --namespace=default
        kubectl get services -o wide
EOF

  # Create README with deployment instructions
  cat > "$TEMP_DIR/README.md" << EOF
# $CLIENT_NAME InfraSearch Deployment

This repository contains the application code and CI/CD pipelines for $CLIENT_NAME's InfraSearch environment.

## Architecture

This application is deployed to a dedicated GKE cluster in its own GCP project with:
- Private VPC network
- Cloud SQL database (if enabled)
- Comprehensive monitoring and security add-ons

## Deployment

The application is automatically deployed to the GKE cluster when code is pushed to the main branch.

### Manual Deployment

If you need to trigger a deployment manually:
1. Go to the "Actions" tab
2. Select the "Deploy to Client GKE Cluster" workflow
3. Click "Run workflow"

## Development

1. Clone this repository
2. Make your changes
3. Push to main branch to trigger deployment

## Accessing the Application

The application is accessible at: https://$CLIENT_NAME.example.com

## Support

For any issues, please contact the platform team.
EOF

  # Commit and push changes
  cd "$TEMP_DIR"
  git add .github/workflows/deploy.yaml README.md
  git commit -m "Setup CI/CD workflow and documentation for $CLIENT_NAME"
  git push
  
  # Clean up
  cd - > /dev/null
  rm -rf "$TEMP_DIR"
  
  echo -e "${GREEN}CI/CD workflow setup successfully.${NC}"
}

# Main function
main() {
  check_prerequisites
  create_github_project
  create_github_repository
  setup_repository_secrets
  setup_cicd_workflow
  
  echo
  echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║                  GitHub Setup Complete                     ║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
  echo -e "${GREEN}✅ GitHub Project: Created${NC}"
  echo -e "${GREEN}✅ GitHub Repository: Created at $REPO_URL${NC}"
  echo -e "${GREEN}✅ CI/CD Pipeline: Configured${NC}"
  
  echo
  echo -e "${BOLD}Next Steps:${NC}"
  echo -e "1. Clone the repository: gh repo clone $GH_ORG/$CLIENT_NAME"
  echo -e "2. Add application code to the repository"
  echo -e "3. Push changes to trigger deployment"
  echo -e "4. Monitor the deployment in GitHub Actions"
}

# Run the main function
main