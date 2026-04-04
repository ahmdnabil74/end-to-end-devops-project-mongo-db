#!/bin/bash

# ============================ Variables ============================
cluster_name="cluster-1-test"
region="eu-central-1"
aws_id="649126925327"
repo_name="goapp-survey"
image_name="$aws_id.dkr.ecr.$region.amazonaws.com/$repo_name:latest"
namespace="go-app-service"

# ============================ Functions ============================

wait_for_addon() {
    local addon_name=$1
    local max_attempts=10
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        status=$(aws eks describe-addon --cluster-name $cluster_name --addon-name $addon_name --region $region --query "addon.status" --output text)
        echo "Addon $addon_name status: $status"

        if [ "$status" == "ACTIVE" ]; then
            echo "$addon_name is ready."
            return 0
        elif [ "$status" == "DEGRADED" ]; then
            echo "$addon_name is DEGRADED. Check cluster nodes and resources."
            return 1
        else
            echo "Waiting for $addon_name to become ACTIVE..."
            sleep 60
        fi
        ((attempt++))
    done
    echo "Timeout waiting for $addon_name to become ACTIVE"
    return 1
}

# ============================ Helm Repos ============================
echo "-------------------- Adding Helm Repos --------------------"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ============================ Terraform ============================
echo "-------------------- Creating EKS / ECR / EBS / Monitoring --------------------"
cd terraform || exit
terraform init
terraform apply -auto-approve
cd ..

# ============================ Update Kubeconfig =====================
echo "-------------------- Update Kubeconfig --------------------"
aws eks update-kubeconfig --name $cluster_name --region $region

# ============================ Wait for EKS Add-ons ==================
echo "-------------------- Checking EKS Add-ons --------------------"
wait_for_addon "coredns" || echo "Warning: CoreDNS not ready, continuing..."
wait_for_addon "aws-ebs-csi-driver" || echo "Warning: EBS CSI Driver DEGRADED, check resources..."

# ============================ Deploy Monitoring =====================
echo "-------------------- Deploying Monitoring via Helm --------------------"
kubectl create ns monitoring 2>/dev/null || echo "Namespace monitoring exists, skipping..."
helm uninstall kube-prometheus-stack -n monitoring 2>/dev/null || echo "Release not found, skipping..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --version 45.29.0

# ============================ Docker Build & Push ===================
echo "-------------------- Remove Previous Docker Image --------------------"
docker rmi -f $image_name || true

echo "-------------------- Build New Docker Image --------------------"
docker build -t $image_name ./go-app/

echo "-------------------- Login to ECR --------------------"
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $aws_id.dkr.ecr.$region.amazonaws.com

echo "-------------------- Push Docker Image --------------------"
docker push $image_name

# ============================ Kubernetes Deployment =================
echo "-------------------- Create Namespace --------------------"
kubectl create ns $namespace 2>/dev/null || echo "Namespace $namespace exists, skipping..."

echo "-------------------- Deploy App --------------------"
kubectl apply -n $namespace -f k8s

echo "-------------------- Wait for all pods to be running --------------------"
kubectl wait --for=condition=ready pod --all -n $namespace --timeout=600s

echo "-------------------- Get NodePort Info --------------------"
kubectl get svc -n $namespace -o wide

# ============================ Access Info ==========================
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
NODE_PORT=$(kubectl get svc go-app-service -n $namespace -o jsonpath='{.spec.ports[0].nodePort}')

echo "-------------------- Access URL --------------------"
echo "Use this URL to access your app:"
echo "http://$NODE_IP:$NODE_PORT"