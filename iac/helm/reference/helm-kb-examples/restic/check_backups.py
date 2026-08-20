#! /usr/bin/env python3

import sys, getopt
import os
import json
import yaml
import subprocess
from datetime import datetime
from dms import alarm

# Parsing command-line arguments
argv = sys.argv[1:]
conf_file = ""
try:
    opts, args = getopt.getopt(argv, "hc:", ["config="])
except getopt.GetoptError:
    print("check_backups.py -c path_to_config")
    sys.exit(2)

for opt, arg in opts:
    if opt == "-h":
        print("check_backups.py -c <path_to_config>")
        sys.exit()
    elif opt in ("-c", "--config"):
        conf_file = arg

# Load environment variables
environment = os.environ["ENV"]
backup_dms_name = os.environ["BACKUP_DMS_NAME"]
backup_dms_key = os.environ["BACKUP_DMS_KEY"]
project_path = os.environ["PROJECT_PATH"]
auth_key_path = os.environ["AUTH_KEY_PATH"]

# Read and parse the configuration file
yaml_string = subprocess.getoutput("cat " + conf_file)
excepts = yaml.safe_load(yaml_string) or {"exceptions": {}}
disabled_hostnames = excepts.get("disabled_hostnames", [])
ignored_tags = excepts.get("ignored_tags", {})
now = datetime.now()

# Load buckets configuration
my_app_path = os.getcwd()
with open(my_app_path + "/buckets.yaml", "r") as stream:
    try:
        buckets = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)
        sys.exit(1)

# Iterate through each bucket and perform the backup check
for key, value in buckets.items():
    bucket = str(key)
    print("Bucket:", bucket)

    # Set environment variables for restic
    os.environ["RESTIC_REPOSITORY"] = buckets[bucket]["endpoint"] + buckets[bucket]["bucket"]
    os.environ["RESTIC_PASSWORD"] = buckets[bucket]["password"]
    os.environ["AWS_ACCESS_KEY_ID"] = buckets[bucket]["access_key"]
    os.environ["AWS_SECRET_ACCESS_KEY"] = buckets[bucket]["secret_key"]

    # Get latest snapshot from restic
    json_string = subprocess.getoutput("restic --no-lock snapshots --latest 1 --json")
    alert = ""
    try:
        backups = json.loads(json_string)
    except json.JSONDecodeError as exc:
        alert = f"Error: during parsing backups for {bucket} bucket. {exc}, {json_string}"
        backups = []

    environment_exceptions = excepts["exceptions"].get(environment, {})
    bucket_exceptions = environment_exceptions.get(bucket, {})

    # Check each backup for its age and exceptions
    for backup in backups:
        backup["time"] = backup["time"][0:21]
        backup_time = datetime.strptime(backup["time"], "%Y-%m-%dT%H:%M:%S.%f")
        short_id = backup["short_id"]
        difference = now - backup_time
        delta = int(divmod(difference.total_seconds(), 3600)[0]) + 1
        tags_string = " ".join(backup["tags"])

        if tags_string in ignored_tags:
            ignore_before = ignored_tags[tags_string]
            ignore_before = datetime.strptime(ignore_before, "%Y-%m-%d")
            if backup_time < ignore_before:
                print(f"{backup['hostname']} is disabled because it made {backup_time}, all backups before {ignore_before} ignored")
                continue

        if backup["hostname"] in disabled_hostnames:
            print(f"check for hostname: {backup['hostname']} is disabled")
            continue

        if delta > 24:
            for path in backup["paths"]:
                path_exceptions = bucket_exceptions.get("path", {})
                if path in path_exceptions and path_exceptions[path] == "disable":
                    print(backup["hostname"], path, "is disabled")
                    continue
                elif any(key in path and path_exceptions[key] == "disable" for key in path_exceptions):
                    print(backup["hostname"], path, "is disabled")
                    continue

                backup_id_exceptions = bucket_exceptions.get("backup_id", {})
                if short_id in backup_id_exceptions and backup_id_exceptions[short_id] == "disable":
                    print(backup["hostname"], "backup_id:", short_id, "is disabled")
                    continue

                alert += f"job: {{ {tags_string} }} path: {{ {backup['hostname']}: {path} }} is too late. Last run was {delta} hrs ago. Allowed limit is 24 hrs!\n"
        print(tags_string, "has been verified.")

    # Send alert if any issues are found
    if alert:
        project = subprocess.getoutput(f"cat {project_path}")
        dms_key = subprocess.getoutput(f"cat {auth_key_path}")
        alarma = {
            "project": project,
            "severity_level": 4,
            "type": "Events::Continuous",
            "source_type": "custom",
            "labels": {
                "trigger": "restic_jobs_mon",
                "source_server": "backup-monitoring-restic",
                "check_type": "check-archive-age",
                "cluster": environment,
                "bucket": buckets[bucket]["endpoint"] + buckets[bucket]["bucket"],
            },
            "annotations": {
                "summary": "Problems with backups",
                "description": alert,
                "alert_markup_format": "markdown",
                "incidents_flow": "backup",
            },
        }

        alarm(json.dumps(alarma), dms_key)
        print("Alert:", alert)

# Send DeadMansSwitch alert
backup_dms = {"labels": {"trigger": "DeadMansSwitch", "dms": backup_dms_name}}
alarm(json.dumps(backup_dms), backup_dms_key)
print("Done.")

sys.exit()
