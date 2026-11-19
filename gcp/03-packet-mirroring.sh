#!/usr/bin/env bash
# Phase 5: Packet Mirroring (collector load balancer + policy)
# Usage: PROJECT_ID=your-project REGION=us-central1 ZONE=us-central1-a ./03-packet-mirroring.sh
# Flags can change; compare with Google's current "Configure Packet Mirroring" docs if a command fails.
set -euo pipefail
: "${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
gcloud config set project "$PROJECT_ID"

# 1. Put the sensor in an unmanaged instance group
gcloud compute instance-groups unmanaged create ids-ig --zone="$ZONE"
gcloud compute instance-groups unmanaged add-instances ids-ig \
  --zone="$ZONE" --instances=suricata-sensor

# 2. Health check and backend service
gcloud compute health-checks create tcp ids-hc --region="$REGION" --port=22
gcloud compute backend-services create ids-backend --region="$REGION" \
  --load-balancing-scheme=INTERNAL --protocol=TCP \
  --health-checks=ids-hc --health-checks-region="$REGION"
gcloud compute backend-services add-backend ids-backend --region="$REGION" \
  --instance-group=ids-ig --instance-group-zone="$ZONE"

# 3. Forwarding rule flagged as the mirroring collector
gcloud compute forwarding-rules create ids-ilb --region="$REGION" \
  --load-balancing-scheme=INTERNAL --network=lab-vpc --subnet=prod-subnet \
  --backend-service=ids-backend --ip-protocol=TCP --ports=ALL \
  --is-mirroring-collector

# 4. Mirroring policy: mirror every VM tagged "mirrored" (never the sensor or Splunk)
gcloud compute packet-mirrorings create lab-mirroring --region="$REGION" \
  --network=lab-vpc --collector-ilb=ids-ilb --mirrored-tags=mirrored --enable

echo "Mirroring configured. Check health: gcloud compute backend-services get-health ids-backend --region=$REGION"
