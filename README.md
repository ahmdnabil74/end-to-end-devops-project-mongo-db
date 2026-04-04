
# 🚀 End-to-End DevOps Project on AWS (EKS)
(imgs/project.png)

This project demonstrates a complete DevOps workflow by provisioning infrastructure, building and deploying an application, and setting up monitoring — all fully automated using a Bash script.

---

## 📌 Project Overview

This project automates:

- Infrastructure provisioning using Terraform  
- Kubernetes cluster setup (Amazon EKS)  
- Docker image build and push to Amazon ECR  
- Application deployment on Kubernetes  
- Monitoring setup using Prometheus & Grafana (via Helm)  

---

## 🏗️ Architecture
🚀 Deployment 

Run the full pipeline:

chmod +x deploy.sh
./deploy.sh
📊 Outputs

After successful deployment:

✅ EKS Cluster is created
✅ Application is deployed
✅ Docker image is pushed to ECR
✅ Monitoring stack is running
✅ All Kubernetes pods are healthy
🌐 Access Application
kubectl get svc -n go-app-service

Then open:

http://<NODE_IP>:<NODE_PORT>
📈 Monitoring

Check monitoring services:

kubectl get svc -n monitoring

Access Grafana / Prometheus via NodePort or port-forward.

## 📸 Screenshots

Terraform apply success
Running pods
Application UI
Grafana dashboard

## 💡 Key Features
- Fully automated DevOps pipeline
- Infrastructure as Code (IaC)
- Cloud-native deployment
- Monitoring integration
- Production-like setup
 
## 🧠 What I Learned
- Building real-world DevOps pipelines
- Managing Kubernetes workloads
- Automating cloud infrastructure
- Integrating monitoring systems
