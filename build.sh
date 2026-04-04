#!/bin/bash

# Variables
cluster_name="cluster-1-test"
region="eu-central-1"
aws_id="649126925327"
repo_name="goapp-survey"
image_name="$aws_id.dkr.ecr.$region.amazonaws.com/$repo_name:latest"
namespace="go-app-service"

# -------------------- Helm Repos --------------------
echo "--------------------Adding Helm Repos--------------------"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# -------------------- Terraform Infrastructure --------------------
echo "--------------------Creating EKS / ECR / EBS / Monitoring--------------------"
cd terraform || exit
terraform init
terraform apply -auto-approve
cd ..

# -------------------- Update Kubeconfig --------------------
echo "--------------------Update Kubeconfig--------------------"
aws eks update-kubeconfig --name $cluster_name --region $region

# -------------------- Deploy Monitoring (Helm) --------------------
echo "--------------------Deploying Monitoring via Helm--------------------"
kubectl create ns monitoring || true

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --version 45.29.0 \
   # -f terraform/kube_monitoring_stack_values.yaml

# -------------------- Docker Build & Push --------------------
echo "--------------------Remove Previous Docker Image--------------------"
docker rmi -f $image_name || true

echo "--------------------Build New Docker Image--------------------"
docker build -t $image_name ./go-app/

echo "--------------------Login to ECR--------------------"
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $aws_id.dkr.ecr.$region.amazonaws.com

echo "--------------------Push Docker Image--------------------"
docker push $image_name

# -------------------- Kubernetes Deployment --------------------
echo "--------------------Create Namespace--------------------"
kubectl create ns $namespace || true

echo "--------------------Deploy App--------------------"
kubectl apply -n $namespace -f k8s

echo "--------------------Wait for all pods to be running--------------------"
sleep 60s

echo "--------------------Get NodePort Info--------------------"
kubectl get svc -n $namespace -o wide

# -------------------- Access Info --------------------
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
NODE_PORT=$(kubectl get svc go-app-service -n $namespace -o jsonpath='{.spec.ports[0].nodePort}')

echo "Use this URL:"
echo "http://$NODE_IP:$NODE_PORT"