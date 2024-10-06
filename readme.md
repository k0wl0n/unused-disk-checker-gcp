# Unused Disk Checker Project

**Automate the detection and cleanup of unused disks in Google Cloud Platform (GCP).**

---

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
  - [Software Requirements](#software-requirements)
  - [Python Dependencies](#python-dependencies)
  - [Environment Variables](#environment-variables)
- [Installation and Setup](#installation-and-setup)
- [Usage](#usage)
  - [Running the Unused Disk Checker](#running-the-unused-disk-checker)
  - [Review and Execute Deletion Script](#review-and-execute-deletion-script)
- [Scripts Overview](#scripts-overview)
- [Flowchart](#flowchart)
- [Configuration](#configuration)
- [Logging](#logging)
- [Security Considerations](#security-considerations)
- [Automation with Cron (Optional)](#automation-with-cron-optional)

---

## Introduction

This project provides a set of scripts to automate the process of identifying and managing unused (unattached) disks across multiple Google Cloud Platform (GCP) projects. It helps in optimizing resource usage and reducing costs by detecting disks that are not in use, generating detailed reports, and facilitating their cleanup.

---

## Features

- **Automated Detection:** Scans specified GCP projects for unused disks.
- **Reporting:** Generates summaries and detailed reports in JSON format.
- **Slack Integration:** Sends notifications and reports to a designated Slack channel.
- **Deletion Script Generation:** Creates a shell script with commands to delete unused disks after review.
- **Logging:** Maintains logs for auditing and troubleshooting purposes.

---

## Prerequisites

### Software Requirements

- **Google Cloud SDK (`gcloud`):** To interact with GCP resources.
- **Python 3:** For running the Python script.
- **Virtual Environment (venv):** Recommended to isolate Python dependencies.
- **`jq`:** For processing JSON in bash scripts.

### Python Dependencies

- **requests**
- **python-dotenv**

### Environment Variables

Set the following environment variables before running the scripts:

| **Environment Variable**          | **Description**                                                                                  | **Example Value**                                                      |
|-----------------------------------|--------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| `SA_COMPUTE_VIEW`                 | Contents of your service account key JSON file (GCP credentials).                                | `export SA_COMPUTE_VIEW=$(cat /path/to/service_account_key.json)`      |
| `SLACK_BOT_TOKEN`                 | Your Slack bot token for sending notifications.                                                  | `export SLACK_BOT_TOKEN="xoxb-xxxxxxxxxxxx-xxxxxxxxxxxx-xxxxxxxxxxxx"` |
| `SLACK_CHANNEL`                   | Slack channel where notifications will be sent.                                                  | `export SLACK_CHANNEL="#your-slack-channel"`                           |
| `SLACK_WEBHOOK_URL`               | Slack webhook URL for sending messages via webhook.                                              | `export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/xxx/yyy/zzz"` |
| `PROJECTS`                        | Comma-separated list of GCP project IDs to check for unused disks (no spaces).                   | `export PROJECTS="project1,project2,project3"`                         |
| `REPORT_DIR`                      | Directory where reports and logs will be stored.                                                 | `export REPORT_DIR="./reports"`                                        |
| `GOOGLE_APPLICATION_CREDENTIALS`  | Path to the service account key JSON file used by Google SDK.                                    | `export GOOGLE_APPLICATION_CREDENTIALS="service_account_key.json"`     |

---

## Installation and Setup

1. **Clone the Repository**

   ```bash
   git clone https://github.com/your-repo/unused-disk-checker.git
   cd unused-disk-checker
   ```

2. **Set Up Environment Variables**

   Export the required environment variables:

   ```bash
   export SA_COMPUTE_VIEW=$(cat /path/to/service_account_key.json)
   export SLACK_BOT_TOKEN="your-slack-bot-token"
   export SLACK_CHANNEL="#your-slack-channel"
   export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your-webhook-url"
   export PROJECTS="project1,project2,project3"
   export REPORT_DIR="./reports"
   export GOOGLE_APPLICATION_CREDENTIALS="service_account_key.json"
   ```

3. **Install Google Cloud SDK**

   Follow the instructions on the [Google Cloud SDK Installation page](https://cloud.google.com/sdk/docs/install) to install `gcloud`.

4. **Verify `gcloud` Installation**

   ```bash
   gcloud version
   ```

5. **Set Up Python Virtual Environment**

   ```bash
   python3 -m venv myenv
   source myenv/bin/activate
   ```

6. **Install Python Dependencies**

   ```bash
   pip install --upgrade pip
   pip install requests python-dotenv
   ```

7. **Install `jq`**

   ```bash
   # For Debian/Ubuntu
   sudo apt-get install jq

   # For macOS using Homebrew
   brew install jq
   ```

---

## Usage

### Running the Unused Disk Checker

1. **Make the Bash Script Executable**

   ```bash
   chmod +x unused_disk_checker.sh
   ```

2. **Run the Script**

   ```bash
   ./unused_disk_checker.sh
   ```

   This script will:

   - Validate environment variables and prerequisites.
   - Authenticate with GCP using the service account.
   - Run the Python script to collect unused disks and send Slack notifications.
   - Generate a deletion script for unused disks.

### Review and Execute Deletion Script

1. **Review the Deletion Script**

   A file named `delete_unused_disks.sh` will be generated if unused disks are found. **Review this script carefully** to ensure that only unnecessary disks will be deleted.

2. **Make the Deletion Script Executable**

   ```bash
   chmod +x delete_unused_disks.sh
   ```

3. **Execute the Deletion Script (Optional)**

   ```bash
   ./delete_unused_disks.sh
   ```

   **Note:** Only execute this script after thorough review and confirmation.

---

## Scripts Overview

### 1. `unused_disk_checker.sh`

The main bash script that orchestrates the process:

- Sets environment variables and validates them.
- Authenticates with GCP using the service account key.
- Writes the Python script (`script.py`) to a file.
- Sets up a Python virtual environment and installs dependencies.
- Executes the Python script.
- Generates the deletion script if unused disks are found.

### 2. `script.py`

Python script that performs the following:

- Collects unused (unattached) disks from specified GCP projects.
- Generates summaries and detailed reports in JSON format.
- Sends notifications and uploads reports to Slack.
- Handles exceptions and sends error notifications to Slack if needed.

### 3. `delete_unused_disks.sh`

Generated by `unused_disk_checker.sh`, this script contains `gcloud` commands to delete the unused disks identified. It ensures that you have control over which disks are deleted after manual review.

---

## Flowchart

```mermaid
graph TD
    A[Start] --> B[Set Environment Variables]
    B --> C{Is SA_COMPUTE_VIEW Set?}
    C -- Yes --> D[Write Service Account Key]
    C -- No --> Z[Exit with Error]
    D --> E[Set GOOGLE_APPLICATION_CREDENTIALS]
    E --> F[Verify gcloud Installation]
    F --> G[Authenticate with Service Account]
    G --> H[Write Python Script to File]
    H --> I[Make Python Script Executable]
    I --> J[Set Up Python Virtual Environment]
    J --> K[Install Dependencies]
    K --> L[Execute Python Script]
    L --> M{Unused Disks Found?}
    M -- Yes --> N[Generate Deletion Commands]
    N --> O[Write Deletion Script]
    O --> P[Make Deletion Script Executable]
    P --> Q[End]
    M -- No --> R[No Action Needed]
    R --> Q[End]
    Z --> Q[End]
```

---

## Configuration

- **Service Account Key (`SA_COMPUTE_VIEW`):**

  - Contains the JSON content of your service account key.
  - Must have the `Compute Viewer` role.
  - Used for authenticating with GCP.

- **Slack Integration:**

  - **Slack Bot Token (`SLACK_BOT_TOKEN`):** Used by the Python script to send messages and upload files to Slack.
  - **Slack Channel (`SLACK_CHANNEL`):** The Slack channel where notifications will be sent.
  - **Slack Webhook URL (`SLACK_WEBHOOK_URL`):** Used in the deletion script to send messages via webhook.

- **Projects (`PROJECTS`):**

  - Comma-separated list of GCP project IDs to check for unused disks.
  - Example: `export PROJECTS="project1,project2,project3"`

- **Report Directory (`REPORT_DIR`):**

  - Directory where reports and logs will be stored.
  - Default is `./reports`.

---

## Logging

- **Log File:** `unused_disks_monitor.log` in the `REPORT_DIR`.
- **Reports:**
  - `unused_disks.json`: Detailed list of unused disks.
  - `disk_summary.json`: Summary of unused disks by type and project.
- **Deletion Script:** `delete_unused_disks.sh` generated if unused disks are found.

---

## Security Considerations

- **Credentials:**

  - Do not commit sensitive credentials like service account keys or Slack tokens to version control.
  - Use environment variables or secure secret management systems to handle credentials.

- **Permissions:**

  - Ensure the service account has the minimum required permissions.
  - Assign `Compute Viewer` role for monitoring.
  - Assign `Compute Storage Admin` role if deletion of disks is intended.

- **Review Before Execution:**

  - Always review the generated `delete_unused_disks.sh` script before executing.
  - Confirm that only the intended disks will be deleted.

---

## Automation with Cron (Optional)

You can schedule the script to run automatically using cron jobs.

```bash
# Example: Run every day at 2:00 AM
0 2 * * * /path/to/unused_disk_checker.sh >> /path/to/cron.log 2>&1
```

---