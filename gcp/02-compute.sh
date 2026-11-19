#!/usr/bin/env bash
# Phase 2: four Ubuntu 22.04 VMs with fixed internal IPs and no public IPs
# Usage: PROJECT_ID=your-project ZONE=us-central1-a ./02-compute.sh
set -euo pipefail
: "${PROJECT_ID:?Set PROJECT_ID}"
ZONE="${ZONE:-us-central1-a}"
gcloud config set project "$PROJECT_ID"

IMG=(--image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud)

gcloud compute instances create splunk-siem --zone="$ZONE" \
  --machine-type=e2-standard-2 --subnet=prod-subnet \
  --private-network-ip=10.10.0.10 --no-address "${IMG[@]}" \
  --boot-disk-size=50GB --boot-disk-type=pd-balanced --tags=splunk

gcloud compute instances create suricata-sensor --zone="$ZONE" \
  --machine-type=e2-standard-2 --subnet=prod-subnet \
  --private-network-ip=10.10.0.20 --no-address "${IMG[@]}" \
  --boot-disk-size=30GB --boot-disk-type=pd-balanced --tags=ids-sensor

gcloud compute instances create web-victim --zone="$ZONE" \
  --machine-type=e2-medium --subnet=prod-subnet \
  --private-network-ip=10.10.0.30 --no-address "${IMG[@]}" \
  --boot-disk-size=20GB --boot-disk-type=pd-balanced --tags=web-victim,mirrored

gcloud compute instances create attacker-vm --zone="$ZONE" \
  --machine-type=e2-medium --subnet=attacker-subnet \
  --private-network-ip=10.20.0.10 --no-address "${IMG[@]}" \
  --boot-disk-size=20GB --boot-disk-type=pd-balanced --tags=attacker

gcloud compute instances list \
  --format="table(name,zone.basename(),networkInterfaces[0].networkIP,status)"
echo "VMs created. Software (Splunk, Suricata, forwarder) is installed manually; see the guide."
