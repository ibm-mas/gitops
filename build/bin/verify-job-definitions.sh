#!/bin/bash


# WORK IN PROGRESS

ROOT_DIR="/home/tom/workspaces/structured/saas/gitops/instance-applications/130-ibm-mas-suite"


# Any file that contains quay.io/ibmmas/cli, MUST also contain:
#   {{- $_job_name_prefix := "postsync-configtool-oidc-job" }}


files=$(grep -Erl --include '*.yaml' 'quay.io/ibmmas/cli:' ${ROOT_DIR})

scanned_count=0
valid_count=0
invalid_count=0

for file in ${files}; do
    problems=""
    (( scanned_count++ ))

    grep -Eq '\{\{-?\s*[[:space:]]*\$_cli_image_tag[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
    rc=$?
    if [[ $rc != 0 ]]; then
        problems='    Missing {{- $_cli_image_tag := "..." }}\n'
    fi

    grep -Eq '\{\{-?\s*[[:space:]]*\$_job_name_prefix[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
    rc=$?
    if [[ $rc != 0 ]]; then
        problems=${problems}'    Missing {{- $_job_name_prefix := "..." }}\n'
        # TODO: check actual value <=52 chars in length?
    fi

    # TODO: check $_job_config_values - a bit different since its value is a dict
    # TODO: maybe we change how these are specified - at least need to try out some examples where we pick specific values out
    # grep -Eq '\{\{-?\s*[[:space:]]*\$_job_config_values[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
    # rc=$?
    # if [[ $rc != 0 ]]; then
    #     problems='    Missing {{- $_job_config_values := "..." }}\n'
    # fi

    grep -Eq '\{\{-?\s*[[:space:]]*\$_job_version[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
    rc=$?
    if [[ $rc != 0 ]]; then
        problems=${problems}'    Missing {{- $_job_version := "..." }}\n'
    fi

    # TODO: check $_job_config_values has specific value

    # TODO: check $_job_name has specific value

    # TODO: any line that has "quay.io/ibmmas/cli" only has quay.io/ibmmas/cli:{{ $_cli_image_tag }}

    # TODO: need to relax rules for resources other than Jobs (where immutability is not an issue - e.g. CronJobs)?

    if [[ -n "$problems" ]]; then
        echo "${file}:"
        echo -e "${problems}"
        (( invalid_count++ ))
    else
         (( valid_count++ ))
    fi
done

echo
echo "Complete"
echo "  ${scanned_count} files scanned"
echo "  ${valid_count} are valid"
echo "  ${invalid_count} are invalid"

if [[ $invalid_count > 0 ]]; then
    echo ""
    echo "Invalid files were found, please see logs above for details"
    echo "Further documentation available at TODO"
    exit 1
fi
