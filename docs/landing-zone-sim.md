# Landing-zone simulation (manual, human only)

In a real company the landing-zone team creates projects through its own
project factory. Here we do the same steps by hand so the platform can start
from "a project already exists". Agents prepare and explain these commands;
**only the human runs them.** Verify roles on first plan and note gaps in the journal.

## Once: teams folder
```bash
gcloud resource-manager folders create --display-name=teams --folder=<NONPROD_FOLDER_ID>
# note the new folder ID → <TEAMS_FOLDER_ID>
```

## Per team project (example: shop / dev)
```bash
TEAM=shop; ENV=dev
PROJECT_ID="${TEAM}-${ENV}-$(openssl rand -hex 2)"   # globally unique; IDs are never reusable
gcloud projects create "$PROJECT_ID" --folder=<TEAMS_FOLDER_ID> \
  --labels=team=$TEAM,env=$ENV,managed-by=landing-zone
gcloud billing projects link "$PROJECT_ID" --billing-account=<BILLING_ACCOUNT_ID>
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com \
  serviceusage.googleapis.com cloudresourcemanager.googleapis.com --project="$PROJECT_ID"

# deploy identities (the platform impersonates these)
gcloud iam service-accounts create deployer --project="$PROJECT_ID" --display-name="Platform deploy (write)"
gcloud iam service-accounts create planner  --project="$PROJECT_ID" --display-name="Platform plan (read)"

for ROLE in roles/compute.admin roles/iam.serviceAccountAdmin roles/iam.serviceAccountUser \
            roles/resourcemanager.projectIamAdmin roles/serviceusage.serviceUsageAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --role="$ROLE" \
    --member="serviceAccount:deployer@${PROJECT_ID}.iam.gserviceaccount.com"
done
for ROLE in roles/viewer roles/iam.securityReviewer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --condition=None --role="$ROLE" \
    --member="serviceAccount:planner@${PROJECT_ID}.iam.gserviceaccount.com"
done
echo "$PROJECT_ID"   # → put into platform/dev.yaml, then re-run bootstrap apply (grants)
```

## Trade-offs to mention in the talk
- `projectIamAdmin` lets `deployer` change IAM in its own project (it could
  grant itself more). A real LZ would restrict grantable roles with IAM
  conditions or use narrower custom roles.
- Never delete these projects during rehearsals: IDs stay reserved and deleted
  projects may still count against the billing account's project quota.
