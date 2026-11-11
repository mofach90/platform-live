# Landing-zone simulation (manual, human only)

In a real company the landing-zone team creates projects through its own
project factory. Here we do the same steps by hand so the platform can start
from "a project already exists". Agents prepare and explain these commands;
**only the human runs them.** Verify roles on first plan and note gaps in the journal.

Run everything from inside `platform-live/`: direnv (`.envrc`) sets the demo's own
`CLOUDSDK_CONFIG` and loads `$NONPROD_FOLDER_ID`, `$TEAMS_FOLDER_ID`,
`$BILLING_ACCOUNT_ID` from the gitignored `.env` (template: `.env.example`).

## Once: teams folder
```bash
gcloud resource-manager folders create --display-name=teams --folder=$NONPROD_FOLDER_ID
# put the new folder ID into .env as TEAMS_FOLDER_ID, then: direnv reload
```

## Per team project (example: shop / dev)
```bash
TEAM=shop; ENV=dev
TEAM_PROJECT_ID="${TEAM}-${ENV}-$(openssl rand -hex 2)"   # globally unique; IDs are never reusable
gcloud projects create "$TEAM_PROJECT_ID" --folder=$TEAMS_FOLDER_ID \
  --labels=team=$TEAM,env=$ENV,managed-by=landing-zone
gcloud billing projects link "$TEAM_PROJECT_ID" --billing-account=$BILLING_ACCOUNT_ID
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com \
  serviceusage.googleapis.com cloudresourcemanager.googleapis.com orgpolicy.googleapis.com \
  --project="$TEAM_PROJECT_ID"

# guardrails (org policies), set BEFORE the platform enables the Compute API.
# No external IPs: at project level, because other projects in the nonprod folder need them.
POLICY_FILE="$(mktemp)"
cat > "$POLICY_FILE" <<EOF
name: projects/${TEAM_PROJECT_ID}/policies/compute.vmExternalIpAccess
spec:
  rules:
  - denyAll: true
EOF
gcloud org-policies set-policy "$POLICY_FILE" && rm "$POLICY_FILE"
# No default network: enforced higher up; this must print "enforce: true".
gcloud org-policies describe compute.skipDefaultNetworkCreation --effective --project="$TEAM_PROJECT_ID"

# deploy identities (the platform impersonates these)
gcloud iam service-accounts create deployer --project="$TEAM_PROJECT_ID" --display-name="Platform deploy (write)"
gcloud iam service-accounts create planner  --project="$TEAM_PROJECT_ID" --display-name="Platform plan (read)"

for ROLE in roles/compute.admin roles/iam.serviceAccountAdmin roles/iam.serviceAccountUser \
            roles/resourcemanager.projectIamAdmin roles/serviceusage.serviceUsageAdmin; do
  gcloud projects add-iam-policy-binding "$TEAM_PROJECT_ID" --condition=None --role="$ROLE" \
    --member="serviceAccount:deployer@${TEAM_PROJECT_ID}.iam.gserviceaccount.com"
done
for ROLE in roles/viewer roles/iam.securityReviewer; do
  gcloud projects add-iam-policy-binding "$TEAM_PROJECT_ID" --condition=None --role="$ROLE" \
    --member="serviceAccount:planner@${TEAM_PROJECT_ID}.iam.gserviceaccount.com"
done

# platform-team humans may impersonate both (local plan, first apply).
# Owner does NOT include iam.serviceAccounts.getAccessToken, so this grant is needed.
ME="user:$(gcloud config get-value account)"
for SA in planner deployer; do
  gcloud iam service-accounts add-iam-policy-binding "${SA}@${TEAM_PROJECT_ID}.iam.gserviceaccount.com" \
    --project="$TEAM_PROJECT_ID" --member="$ME" --role=roles/iam.serviceAccountTokenCreator --condition=None
done
# done-when check (IAM can take a few minutes to propagate):
gcloud projects describe "$TEAM_PROJECT_ID" \
  --impersonate-service-account="planner@${TEAM_PROJECT_ID}.iam.gserviceaccount.com" --format="value(projectId)"

echo "$TEAM_PROJECT_ID"   # → put into platform/dev.yaml, then re-run bootstrap apply (grants)
```

## Trade-offs to mention in the talk
- The external-IP policy is set per project by hand. A real LZ sets guardrails on a
  folder so every new project inherits them; here another nonprod project needs
  external IPs. The VM module also never assigns one (two layers: code default + policy).
- The human token-creator grant is permanent here. A real LZ grants it to a
  platform-admins group, ideally just-in-time via Privileged Access Manager.
- `projectIamAdmin` lets `deployer` change IAM in its own project (it could
  grant itself more). A real LZ would restrict grantable roles with IAM
  conditions or use narrower custom roles.
- Never delete these projects during rehearsals: IDs stay reserved and deleted
  projects may still count against the billing account's project quota.
