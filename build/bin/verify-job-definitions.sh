#!/bin/bash

function print_help() {
  cat << EOM
Usage: verify-job-definitions.sh [OPTION] [PATH]....

Check that YAML files containing a reference to the quay.io/ibmmas/cli image conform to the following constraints:
    - The \$_cli_image_tag constant is defined
    - The \$_cli_image_tag constant is used for all quay.io/ibmmas/cli image tags

Additional constraints are imposed for YAML files containing Job definitions that lack the argocd.argoproj.io/hook annotation, 
or have the annotation but apply only the HookFailed argocd.argoproj.io/hook-delete-policy.

These additional constraints are intended to protect against making changes to the Job
(e.g. updating \$_cli_image_tag, or changing some other immutable Job field) without also updating the
Job name accordingly:
    - The \$_job_name_prefix constant is defined, and is at most 5 chars in length
    - The \$_job_config_values constant is defined
    - The \$_job_version constant is defined
    - The \$_job_hash constant is defined and has the correct value
    - The \$_job_name constant is defined, has the correct value and is used as the name of the Job
    - The \$_job_cleanup_group is constant defined and assigned to the mas.ibm.com/job-cleanup-group Job label
    - each template file contains only a single Job definition

[PATH]... can be either:
    - A single directory: the script will check all files under this directory (recursive)
    - Any number of paths to individual YAML files

[OPTION]:
    -h      Print this help message and exit

Example:
    verify-job-definitions.sh /home/tom/workspace/gitops
    verify-job-definitions.sh \\
        /home/tom/workspace/gitops/instance-applications/010-ibm-sync-jobs/templates/00-aws-docdb-add-user_Job.yaml \\
        /home/tom/workspace/gitops/instance-applications/510-550-ibm-mas-suite-app-config/templates/700-702-postsync-db2-manage.yaml
EOM
}

while getopts h flag
do
    case "${flag}" in
        h) 
            print_help
            exit 0
        ;;
        ?)
            print_help
            exit 1
        ;;

    esac
done
shift $((OPTIND - 1))


# if single PATH, check if it's a dir
#   if so, scan it for yaml files containing references to quay.io/ibmmas/cli
#   otherwise, we'll treat it as a file
if [[ $# == 1 ]]; then
    path=$1
    if [[ -d $path ]]; then
        files=$(grep -Erl --include '*.yaml' 'quay.io/ibmmas/cli' ${path})
        echo "Checking all YAML files with quay.io/ibmmas/cli references under directory ${path}"
        echo "---------"
        shift
    fi
fi

# if >1 path, all must be files
file_count=$#
while [[ $# -gt 0 ]]
do
    path=$1
    if [[ -d $path ]]; then
        echo "Only a single [PATH] can be specified when referencing a directory"
        print_help
        exit 1
    elif [[ -f $path ]]; then
        files="${files} ${path}"
    else
        echo "Specified [PATH] $path is not valid"
        print_help
        exit 1
    fi
    shift
done

if [[ $file_count -gt 0 ]]; then
    echo "Checking $file_count files"
    echo "---------"
fi

scanned_count=0
valid_count=0
invalid_count=0
skipped_count=0

for file in ${files}; do


    problems=""
    (( scanned_count++ ))

    # Skip the file if it does not contain a reference to quay.io/ibmmas/cli
    grep -Eq 'quay.io/ibmmas/cli' ${file}
    rc=$?
    if [[ $rc != 0 ]]; then
        (( skipped_count++ ))
        continue
    fi


    # Check $_cli_image_tag constant is defined (and is a string)
    grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_cli_image_tag[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
    rc=$?
    if [[ $rc != 0 ]]; then
        problems='    Missing {{- $_cli_image_tag := "..." }}\n'
    fi

    # Any line that has "quay.io/ibmmas/cli" must match quay.io/ibmmas/cli:{{ $_cli_image_tag }}
    while IFS= read -r cli_image_ref; do 
        grep -Eq '\{\{-?[[:space:]]+\$_cli_image_tag[[:space:]]*\}\}' <<< "$cli_image_ref"
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    Invalid CLI image tag found: "'${cli_image_ref}'" (should be "{{ $_cli_image_tag }}")\n'
        fi
    done <<< "$(sed -En 's/.*quay\.io\/ibmmas\/cli:(.*)/\1/p' $file)"


    # Attempt to dynamically detect if we can relax job naming restrictions for this file
    # The following awk commands exits 0 if and only if:
    #   - File does not contain a Job resource 
    #       Jobs are currently the only resource we use where immutability of the image field is a problem.
    #       e.g. it's fine to modify the image field of a CronJob resource
    #   - All Jobs have argocd.argoproj.io/hook
    #   - No job has JUST argocd.argoproj.io/hook-delete-policy: HookFailed
    #       HookFailed is the only delete policy where we might encounter immutability issues
    #       This works because if multiple policies specified, then it must also have either HookSucceeded or BeforeHookCreation
    #       or, if the annotation is omitted, the policy defaults to BeforeHookCreation
    awkout=$(awk 'BEGIN { found=0; job_count=0; hook_count=0; hf_detected=0 }
        /^[[:space:]]*kind:[[:space:]]+Job/ { inJob=1; job_count++ }
        /^---/ { inJob=0 }
        inJob && /argocd\.argoproj\.io\/hook:/ { hook_count++ }
        inJob && /argocd\.argoproj\.io\/hook-delete-policy:[[:space:]]+HookFailed[[:space:]]*$/ { hf_detected=1 }
        END {
            if(hook_count!=job_count) {
                print "At least one Job is not annotated with argocd.argoproj.io/hook"
                exit 1
            }
            if(hf_detected==1) {
                print "At least one Job with argocd.argoproj.io/hook-delete-policy: HookFailed was detected"
                exit 1
            }
        }' $file \
    )
    enforce_job_naming_conventions=$?
    
    if [[ $enforce_job_naming_conventions == 1 ]]; then

        # Check $_job_name_prefix constant is defined (and is a string)
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_job_name_prefix[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
        rc=$?
        if [[ $rc == 0 ]]; then
            # check $_job_name_prefix is <=52 chars in length
            while IFS= read -r job_name_prefix; do
                job_name_prefix_len=$(echo -n "${job_name_prefix}" | wc -m)
                if [[ $job_name_prefix_len > 52 ]]; then
                    problems=${problems}'    Invalid $_job_name_prefix value found: "'${job_name_prefix}'" (must at most 52 chars but is currently '${job_name_prefix_len}')\n'
                fi
        done <<< "$(sed -En 's/^[[:space:]]*\{\{-?[[:space:]]+\$_job_name_prefix[[:space:]]*:=[[:space:]]*"([^"]+)"[[:space:]]*\}\}/\1/p' $file)"
        else
            problems=${problems}'    Missing {{- $_job_name_prefix := "..." }}\n'
        fi

        # Check $_job_config_values constant is defined
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_job_config_values[[:space:]]*:=[^}]+\}' $file
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    Missing {{- $_job_config_values := ... }}\n'
        fi

        # Check $_job_version constant is defined (and is a string)
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_job_version[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    Missing {{- $_job_version := "..." }}\n'
        fi

        # check $_job_hash constant is defined
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_job_hash[[:space:]]*:=[^}]+\}' $file
        rc=$?
        if [[ $rc == 0 ]]; then
            # check $_job_hash has correct value
            while IFS= read -r job_hash_value; do
                grep -Eq '^[[:space:]]*print[[:space:]]+\([[:space:]]*\$_job_config_values[[:space:]]*\|[[:space:]]*toYaml[[:space:]]*\)[[:space:]]+\$_cli_image_tag[[:space:]]+\$_job_version[[:space:]]*\|[[:space:]]*adler32sum' <<< "$job_hash_value"
                rc=$?
                if [[ $rc != 0 ]]; then
                    problems=${problems}'    Invalid $_job_hash value found: "'${job_hash_value}'" (should be "print ($_job_config_values | toYaml) $_cli_image_tag $_job_version | adler32sum")\n'
                fi
            done <<< "$(sed -En 's/^[[:space:]]*\{\{-?[[:space:]]+\$_job_hash[[:space:]]*:=[[:space:]]*([^}]+)\}\}/\1/p' $file)"
        else
            problems=${problems}'    Missing {{- $_job_hash := "..." }}\n'
        fi


        # check $_job_name is constant is defined
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]*\$_job_name[[:space:]]*:=[^}]+\}' $file
        rc=$?
        if [[ $rc == 0 ]]; then
            # check $_job_name has correct value
            while IFS= read -r job_name_value; do
                grep -Eq '^[[:space:]]*join[[:space:]]*"-"[[:space:]]*\([[:space:]]*list[[:space:]]*\$_job_name_prefix[[:space:]]*\$_job_hash[[:space:]]*\)[[:space:]]*' <<< "$job_name_value"
                rc=$?
                if [[ $rc != 0 ]]; then
                    problems=${problems}'    Invalid $_job_name value found: "'${job_name_value}'" (should be "join "-" (list $_job_name_prefix $_job_hash)")\n'
                fi
            done <<< "$(sed -En 's/^[[:space:]]*\{\{-?[[:space:]]+\$_job_name[[:space:]]*:=[[:space:]]*([^}]+)\}\}/\1/p' $file)"
        else
            problems=${problems}'    Missing {{- $_job_name := "..." }}\n'
        fi

        # Check there is exactly one Job resource defined in the file
        awkout=$(awk 'BEGIN { job_count=0; }
            /^[[:space:]]*kind:[[:space:]]+Job/ { job_count++ }
            END {
                if(job_count != 1) {
                    printf "Exactly 1 Job should be defined in each template file, but %s were found", job_count
                    exit 1
                }
            }' $file \
        )
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    '${awkout}'\n'
        fi

        # Check the job actually uses $_job_name
        awkout=$(awk 'BEGIN { job_count=0; valid_name_count=0; }
            /^[[:space:]]*kind:[[:space:]]+Job/ { inJob=1; job_count++ }
            /^---/ { inJob=0 }
            inJob && /name:[[:space:]]+\{\{[[:space:]]*\$_job_name[[:space:]]*\}\}/ { valid_name_count++ }
            END {
                if(valid_name_count!=job_count) {
                    print "The Job does not have name: {{ $_job_name }}"
                    exit 1
                }
            }' $file \
        )
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    '${awkout}'\n'
        fi



        # Check $_job_cleanup_group constant is defined
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_job_cleanup_group[[:space:]]*:=[^}]+\}' $file
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    Missing {{- $_job_cleanup_group := ... }}\n'
        fi

        # Check mas.ibm.com/job-cleanup_group: $_job_cleanup_group label is applied to the Job
        awkout=$(awk 'BEGIN { state=0; found=0 }
            /^---/ { state=0 }
            /^[[:space:]]*spec:/ { state=0 }
            /^[[:space:]]*kind:[[:space:]]+Job/ { state=1; }
            state==1 && /^[[:space:]]*metadata:/ { state=2; }
            state==2 && /^[[:space:]]+labels:/ { state=3; }
            state==3 && /^[[:space:]]+mas\.ibm\.com\/job-cleanup-group[[:space:]]*:[[:space:]]+\{\{[[:space:]]*\$_job_cleanup_group[[:space:]]*\}\}/ { found=1 }
            END {
                if(found!=1) {
                    print "The Job does not have the mas.ibm.com/job-cleanup-group: {{ $_job_cleanup_group }} label"
                    exit 1
                }
            }' $file \
        )
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    '${awkout}'\n'
        fi

    fi


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
echo "  ${scanned_count} file(s) scanned"
echo "     ${valid_count} valid"
echo "     ${invalid_count} invalid"
echo "     ${skipped_count} skipped"

if [[ $invalid_count > 0 ]]; then
    echo ""
    echo "Invalid files were found, please consult logs above for details"
    exit 1
fi
