#!/bin/bash

export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your-slack-webhook-url"

# File to store deletion commands
delete_commands_file="delete_unused_disks.sh"

# Remove existing file if it exists
if [ -f "$delete_commands_file" ]; then
    rm "$delete_commands_file"
fi

# List of projects to check for unused disks
projects=(
  "project1"
  "project2"
  "project3"
)

# Loop through each project
for project in "${projects[@]}"; do
    echo "Processing project: $project"

    # Get list of unused disks in JSON format
    disks=$(gcloud compute disks list --filter="-users:*" --project="$project" --format="json")

    # Check if there are any disks to delete
    count=$(echo "$disks" | jq 'length')
    if [ "$count" -eq 0 ]; then
        echo "No unused disks found in project: $project"
        continue
    fi

    # Parse the JSON output and generate deletion commands
    echo "$disks" | jq -r '.[] | "gcloud compute disks delete \(.name) --zone=\(.zone | split("/")[ -1 ]) --project='"$project"' -q"' >> "$delete_commands_file"
done

# Make the deletion script executable if it was created
if [ -f "$delete_commands_file" ]; then
    chmod +x "$delete_commands_file"
    echo -e "\nDeletion commands have been written to $delete_commands_file"
    echo "Review the file before executing to ensure correctness."
else
    echo -e "\nNo unused disks found in any project. No deletion script created."

    # Optional: Send a Slack message using the environment variable
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' --data '{
            "text": "No unused disks found in any project. No deletion script created."
        }' "$SLACK_WEBHOOK_URL"
    else
        echo "SLACK_WEBHOOK_URL is not set. Cannot send Slack notification."
    fi
fi
