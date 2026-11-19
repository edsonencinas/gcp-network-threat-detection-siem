#!/usr/bin/env bash
# Delete all lab resources (dependencies first). Safe to re-run.
# Simplest alternative: gcloud projects delete "$PROJECT_ID"
# Usage: PROJECT_ID=your-project REGION=us-central1 ZONE=us-central1-a ./teardown.sh
set -uo pipefail
: "${PROJECT_ID:?Set PROJECT_ID}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
gcloud config set project "$PROJECT_ID"

echo "This will delete the lab resources in project $PROJECT_ID."
read -r -p "Type 'yes' to continue: " ok
[ "$ok" = "yes" ] || { echo "Aborted."; exit 1; }

gcloud compute packet-mirrorings delete lab-mirroring --region="$REGION" -q
gcloud compute forwarding-rules delete ids-ilb --region="$REGION" -q
gcloud compute backend-services delete ids-backend --region="$REGION" -q
gcloud compute health-checks delete ids-hc --region="$REGION" -q
gcloud compute instance-groups unmanaged delete ids-ig --zone="$ZONE" -q

gcloud compute instances delete splunk-siem suricata-sensor web-victim attacker-vm \
  --zone="$ZONE" -q

gcloud compute routers nats delete lab-nat --router=lab-router --region="$REGION" -q
gcloud compute routers delete lab-router --region="$REGION" -q

for r in allow-iap-ssh allow-iap-splunk-web allow-splunk-ingest \
         allow-attacker-to-victim allow-mirror-to-collector deny-attacker-10-20-0-10; do
  gcloud compute firewall-rules delete "$r" -q
done

gcloud compute networks subnets delete prod-subnet attacker-subnet --region="$REGION" -q
gcloud compute networks delete lab-vpc -q

# Only if you completed the optional Phase 12
gcloud logging sinks delete vpc-to-pubsub -q
gcloud pubsub subscriptions delete vpc-logs-sub -q
gcloud pubsub topics delete vpc-logs -q

echo "Teardown finished. Check Billing > Reports to confirm charges stop."
