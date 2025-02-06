#!/bin/bash

# Assisted by watsonx Code Assistant

function print_help() {
  cat << EOM
Usage: set-cli-image-tag.sh [OPTION]
Replace value of the \$_cli_image_tag constant with a given tag for all .yaml and .yml files in a given directory (and its sub-directories).

    -d, --root-dir   Directory to (recursively) search for .yml and .yaml files
    -t, --tag        The new value for \$_cli_image_tag
    -h, --help       Print this help message and exit

Example:
    set-cli-image-tag.sh --root-dir /home/tom/workspace/gitops --tag 13.2.1
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
        -t|--tag)
        TAG=$1
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
: ${TAG?"Need to set -t|--tag argument"}

scanned_count=0
updated_count=0
for file in $(find ${ROOT_DIR} -type f \( -name "*.yaml" -o -name "*.yml" \)); do
    (( scanned_count++ ))
    before_cksum=$(cksum "$file")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -Ei '' 's/(\{\{-?\s*[[:space:]]*\$_cli_image_tag[[:space:]]*:=[[:space:]]*")([^"]*)("[[:space:]]*\}\})/\1'${TAG}'\3/g' ${file}
    else
        sed -Ei 's/(\{\{-?\s*[[:space:]]*\$_cli_image_tag[[:space:]]*:=[[:space:]]*")([^"]*)("[[:space:]]*\}\})/\1'${TAG}'\3/g' ${file}
    fi
    after_cksum=$(cksum "$file")
    if [[ "$before_cksum" != "$after_cksum" ]]; then
        (( updated_count++ ))
    fi
done

echo "Complete:"
echo "   ${scanned_count} file(s) scanned"
echo "   ${updated_count} file(s) updated"
