#!/bin/bash


# WORK IN PROGRESS




# whitespace-separated list of files to relax job naming restrictions on

# This should only be used in cases where we know Job resource immutability problems when the cli_image_tag is updated
# will not be hit (e.g. due to use of argocd.argoproj.io/hook-delete-policy)

# TODO: allow to be loaded from a separate file / which is maintained by calls to this script
# TODO: use paths to files rather than names (relative to root dir?) to avoid accidental matches against
# files with the same name but under a different directory

RELAX_FILES_LIST="10-postsync-report-starter.yaml 00-presync-report-starter.yaml 04-postsync-mvi-verify.yaml 04-postsync-mvi-sanity.yaml 04-postsync-maximoit-verify.yaml 04-postsync-maximoit-sanity.yaml 04-postsync-manage-verify.yaml"


function print_help() {
  cat << EOM
Usage: verify-job-definitions.sh [OPTION]
TODO description

    -d, --root-dir   Directory to (recursively) search for .yml and .yaml files
    -t, --tag        The new value for \$_cli_image_tag
    -h, --help       Print this help message and exit

Example:
    verify-job-definitions.sh --root-dir /home/tom/workspace/gitops
EOM
}

# Process command line arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -d|--root-dir)
        ROOT_DIR=$1
        shift
        ;;
        -h|--help)
        print_help
        ;;
        *)
        # unknown option
        echo -e "\nUsage Error: Unsupported flag \"${key}\"\n\n"
        print_help
        exit 1
        ;;
    esac
done

: ${ROOT_DIR?"Need to set -d|--root-dir) argument"}

# Checks are performed against any file where a reference to the cli image is detected
files=$(grep -Erl --include '*.yaml' 'quay.io/ibmmas/cli' ${ROOT_DIR})

scanned_count=0
valid_count=0
invalid_count=0

for file in ${files}; do
    problems=""
    (( scanned_count++ ))

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


    # TODO: perhaps we do not need to enforce strict rules on job names for those annotated with
    # argocd.argoproj.io/hook: PreSync, PostSync or PostDelete?
    # (and argocd.argoproj.io/hook-delete-policy: BeforeHookCreation and/or HookSucceeded?
    # (ArgoCD handles immutability problems for us in these cases)
    # perhaps for CronJobs too?

    # Perhaps we could allow devs to specify a list of files to relax job naming restrictions on?
    # (_cli_image_tag constraints should always be enforced however!)

    relax_for_file=0
    filename=$(basename $file)
    for relax_filename in $RELAX_FILES_LIST; do
        if [[ $filename == $relax_filename ]]; then
            relax_for_file=1
            break
        fi
    done

    if [[ $relax_for_file == 0 ]]; then

        # Check $_job_name_prefix constant is defined (and is a string)
        grep -Eq '^[[:space:]]*\{\{-?[[:space:]]+\$_job_name_prefix[[:space:]]*:=[[:space:]]*"[^"]+"[[:space:]]*\}\}' $file
        rc=$?
        if [[ $rc == 0 ]]; then
            # TODO: it's sometimes necessary for job prefix names to be generated
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

        # Check the job actually uses $_job_name
        # This isn't a perfect check - it just verifies that there is at least one instance of name: {{ $_job_name }}
        # in the file, not that it is assigned to a (the) Job resource.
        # Definitely possible to fool the validator here, but I think this will catch most cases.
        grep -Eq '^[[:space:]]+name:[[:space:]]+\{\{[[:space:]]*\$_job_name[[:space:]]*\}\}' $file
        rc=$?
        if [[ $rc != 0 ]]; then
            problems=${problems}'    Missing "name: {{ $_job_name }}"\n'
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
echo "  ${scanned_count} files scanned"
echo "  ${valid_count} are valid"
echo "  ${invalid_count} are invalid"

if [[ $invalid_count > 0 ]]; then
    echo ""
    echo "Invalid files were found, please see logs above for details"
    echo "Further documentation available at TODO"
    exit 1
fi
