#!/usr/bin/env bash
# Phase 1: VPC, subnets, Cloud NAT, firewall rules
# Usage: PROJECT_ID=your-project REGION=us-central1 ./01-network.sh
set -euo pipefail
: "${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-us-central1}"

gcloud config set project "$PROJECT_ID"
gcloud services enable compute.googleapis.com iap.googleapis.com \
  logging.googleapis.com pubsub.googleapis.com

# VPC and subnets
gcloud compute networks create lab-vpc --subnet-mode=custom
gcloud compute networks subnets create prod-subnet \
  --network=lab-vpc --region="$REGION" --range=10.10.0.0/24 \
  --enable-private-ip-google-access
gcloud compute networks subnets create attacker-subnet \
  --network=lab-vpc --region="$REGION" --range=10.20.0.0/24 \
  --enable-private-ip-google-access

# Cloud Router + NAT (VMs have no public IPs)
gcloud compute routers create lab-router --network=lab-vpc --region="$REGION"
gcloud compute routers nats create lab-nat --router=lab-router --region="$REGION" \
  --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges

# Firewall rules
# 1. SSH via Identity-Aware Proxy
gcloud compute firewall-rules create allow-iap-ssh --network=lab-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:22 \
  --source-ranges=35.235.240.0/20

# 2. Splunk Web only through the IAP tunnel
gcloud compute firewall-rules create allow-iap-splunk-web --network=lab-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:8000 \
  --source-ranges=35.235.240.0/20 --target-tags=splunk

# 3. Forwarder (sensor) to Splunk indexer
gcloud compute firewall-rules create allow-splunk-ingest --network=lab-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:9997 \
  --source-tags=ids-sensor --target-tags=splunk

# 4. Attacker subnet to victim (LAB ONLY)
gcloud compute firewall-rules create allow-attacker-to-victim --network=lab-vpc \
  --direction=INGRESS --action=ALLOW --rules=tcp:0-65535,icmp \
  --source-ranges=10.20.0.0/24 --target-tags=web-victim

# 5. Mirrored packets and health checks reaching the collector
gcloud compute firewall-rules create allow-mirror-to-collector --network=lab-vpc \
  --direction=INGRESS --action=ALLOW --rules=all \
  --source-ranges=0.0.0.0/0 --target-tags=ids-sensor

echo "Network foundation created."
