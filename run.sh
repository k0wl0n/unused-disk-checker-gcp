#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

export SLACK_BOT_TOKEN="your-slack-bot-token"
export SLACK_CHANNEL="#your-slack-channel"
export PROJECTS="project1,project2,project3"
export REPORT_DIR="./reports"
export SA_COMPUTE_VIEW="your google Service Account"

# Validate that SA_COMPUTE_VIEW is set
if [[ -z "$SA_COMPUTE_VIEW" ]]; then
  echo "Error: SA_COMPUTE_VIEW environment variable is not set."
  exit 1
fi

# Write the service account key to a JSON file
printf '%s' "$SA_COMPUTE_VIEW" > service_account_key.json

# Set Google Application Credentials
export GOOGLE_APPLICATION_CREDENTIALS="service_account_key.json"

# Verify gcloud is installed
echo "Verifying gcloud installation..."
if ! command -v gcloud &> /dev/null
then
    echo "gcloud could not be found. Please install the Google Cloud SDK."
    exit 1
fi

# Check gcloud version
gcloud version

# Authenticate with the service account
echo "Authenticating with Google Cloud..."
gcloud auth activate-service-account --key-file=service_account_key.json

# Verify authentication
gcloud auth list

echo "Writing Python script to file"

# Use single quotes to prevent variable and command substitution
cat <<'EOF' > script.py
#!/usr/bin/env python3

import subprocess
import json
from collections import defaultdict
import requests
import os
import logging
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration Variables
SLACK_BOT_TOKEN = os.environ.get('SLACK_BOT_TOKEN')
SLACK_CHANNEL = os.environ.get('SLACK_CHANNEL', '#your-slack-channel')
projects_env = os.environ.get('PROJECTS', '')
projects = [proj.strip() for proj in projects_env.split(',') if proj.strip()]
REPORT_DIR = os.environ.get('REPORT_DIR', './reports')
GOOGLE_APPLICATION_CREDENTIALS = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
if GOOGLE_APPLICATION_CREDENTIALS:
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = GOOGLE_APPLICATION_CREDENTIALS

# Validate critical environment variables
if not SLACK_BOT_TOKEN:
    logging.error("SLACK_BOT_TOKEN is not set.")
    sys.exit(1)
if not projects:
    logging.error("No projects specified in the PROJECTS environment variable.")
    sys.exit(1)

# Configure Logging
LOG_FILE = os.path.join(REPORT_DIR, 'unused_disks_monitor.log')
os.makedirs(REPORT_DIR, exist_ok=True)
logging.basicConfig(filename=LOG_FILE, level=logging.INFO,
                    format='%(asctime)s %(levelname)s %(message)s')

def collect_unused_disks():
    logging.info("Starting to collect unused disks.")
    all_disks = []
    for project in projects:
        logging.info(f"Collecting disks from project: {project}")
        command = [
            "gcloud", "compute", "disks", "list",
            "--filter=-users:*",
            f"--project={project}",
            "--format=json(name,zone,sizeGb,type,status)"
        ]
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=300)
            disks = json.loads(result.stdout)
            if not disks:
                logging.info(f"No unused disks found in project: {project}")
                continue
            for disk in disks:
                disk['project'] = project
                zone = disk['zone'].split('/')[-1]
                disk_name = disk['name']
                disk['console_url'] = f"https://console.cloud.google.com/compute/disksDetail/zones/{zone}/disks/{disk_name}?project={project}"
            all_disks.extend(disks)
        except subprocess.CalledProcessError as e:
            error_msg = f"Error collecting disks from project {project}: {e.stderr}"
            logging.error(error_msg)
            continue
        except json.JSONDecodeError as e:
            logging.error(f"JSON decode error for project {project}: {e}")
    UNUSED_DISKS_FILE = os.path.join(REPORT_DIR, 'unused_disks.json')
    try:
        with open(UNUSED_DISKS_FILE, 'w') as json_file:
            json.dump(all_disks, json_file, indent=2)
        logging.info(f"Exported disk data to {UNUSED_DISKS_FILE}")
    except IOError as e:
        logging.error(f"Failed to write unused disks to file: {e}")
    return all_disks

def generate_disk_summary(all_disks):
    type_sums = defaultdict(int)
    project_sums = defaultdict(int)
    total_disks = len(all_disks)
    total_size = 0
    for disk in all_disks:
        try:
            disk_type = disk['type'].split('/')[-1]
            size_gb = int(disk['sizeGb'])
        except (KeyError, ValueError) as e:
            logging.warning(f"Skipping disk due to invalid data: {disk}. Error: {e}")
            continue
        type_sums[disk_type] += size_gb
        project_sums[disk['project']] += size_gb
        total_size += size_gb
    summary = {
        'total_disks': total_disks,
        'total_size_gb': total_size,
        'disk_type_summary': dict(type_sums),
        'project_summary': dict(project_sums)
    }
    DISK_SUMMARY_FILE = os.path.join(REPORT_DIR, 'disk_summary.json')
    try:
        with open(DISK_SUMMARY_FILE, 'w') as summary_file:
            json.dump(summary, summary_file, indent=2)
        logging.info(f"Exported disk summary to {DISK_SUMMARY_FILE}")
    except IOError as e:
        logging.error(f"Failed to write disk summary to file: {e}")
    return summary

def send_slack_notification(all_disks, summary):
    if summary['total_disks'] == 0:
        logging.info("No unused disks found. No Slack notification will be sent.")
        return
    message = "*Unused Google Cloud Disks Detected:*\n\n"
    message += f"- Total unused disks: *{summary['total_disks']}*\n"
    message += f"- Total size: *{summary['total_size_gb']} GB*\n\n"
    message += "*Disk Size Summary by Type:*\n"
    for disk_type, total_size in summary['disk_type_summary'].items():
        message += f"- `{disk_type}`: `{total_size} GB`\n"
    message += "\n*Disk Size Summary by Project:*\n"
    for project, total_size in summary['project_summary'].items():
        message += f"- `{project}`: `{total_size} GB`\n"
    message += "\n*Unused Disks Details:*\n"
    for disk in all_disks:
        disk_info = (
            f"- Project: `{disk['project']}`, Disk Name: `<{disk['console_url']}|{disk['name']}>`, "
            f"Zone: `{disk['zone'].split('/')[-1]}`, Size: `{disk['sizeGb']} GB`, Type: `{disk['type'].split('/')[-1]}`"
        )
        message += disk_info + "\n"
    message += "\nDetailed logs have been uploaded."
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {SLACK_BOT_TOKEN}'
    }
    payload = {
        "channel": SLACK_CHANNEL,
        "text": message
    }
    try:
        response = requests.post('https://slack.com/api/chat.postMessage', headers=headers, json=payload, timeout=10)
        response_data = response.json()
        if not response_data.get('ok'):
            error_msg = f"Failed to send Slack message: {response_data.get('error')}"
            logging.error(error_msg)
    except Exception as e:
        error_msg = f"Error sending Slack message: {e}"
        logging.error(error_msg)
    files_to_upload = [
        os.path.join(REPORT_DIR, 'unused_disks.json'),
        os.path.join(REPORT_DIR, 'disk_summary.json')
    ]
    for file_path in files_to_upload:
        try:
            with open(file_path, 'rb') as file_content:
                response = requests.post(
                    'https://slack.com/api/files.upload',
                    headers={'Authorization': f'Bearer {SLACK_BOT_TOKEN}'},
                    data={
                        'channels': SLACK_CHANNEL,
                        'initial_comment': f'File upload: {os.path.basename(file_path)}'
                    },
                    files={'file': file_content},
                    timeout=30
                )
                response_data = response.json()
                if not response_data.get('ok'):
                    error_msg = f"Failed to upload file {file_path}: {response_data.get('error')}"
                    logging.error(error_msg)
                else:
                    logging.info(f"Uploaded file {file_path} to Slack.")
        except Exception as e:
            error_msg = f"Error uploading file {file_path}: {e}"
            logging.error(error_msg)

def notify_slack_error(e):
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {SLACK_BOT_TOKEN}'
    }
    payload = {
        "channel": SLACK_CHANNEL,
        "text": f":x: *Error in Unused Disks Monitoring Script:*\n```{e}```"
    }
    try:
        response = requests.post('https://slack.com/api/chat.postMessage', headers=headers, json=payload, timeout=10)
        response_data = response.json()
        if not response_data.get('ok'):
            logging.error(f"Failed to send error Slack message: {response_data.get('error')}")
    except Exception as slack_error:
        logging.error(f"Failed to send error notification to Slack: {slack_error}")

def main():
    try:
        logging.info("Unused disks monitoring script started.")
        all_disks = collect_unused_disks()
        summary = generate_disk_summary(all_disks)
        send_slack_notification(all_disks, summary)
        logging.info("Unused disks monitoring script completed successfully.")
    except Exception as e:
        logging.exception("An unexpected error occurred during script execution.")
        notify_slack_error(e)

if __name__ == '__main__':
    main()
EOF

# Make the Python script executable
chmod +x script.py

echo "Setting up Python virtual environment..."
python3 -m venv myenv
source myenv/bin/activate

# Upgrade pip and install dependencies
pip install --upgrade pip
pip install requests python-dotenv

echo "Executing Python script..."
python3 script.py > python_script_output.log 2>&1
