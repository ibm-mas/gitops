#!/bin/bash

# Check that all template files under a given directory define $_cli_image_digest
# with the same value.  Any divergence means someone updated the digest in only
# a subset of files, which must be treated as an error.
#
# Usage: verify-all-cli-digests-the-same.sh <directory>

function print_help() {
  cat << EOM
Usage: verify-all-cli-digests-the-same.sh <directory>

Scan all YAML/YML/TPL files under <directory> that reference quay.io/ibmmas/cli
and verify that every \$_cli_image_digest assignment uses the same digest value.

Exits 0 if all digests are identical, 1 if any divergence is found.
EOM
}

if [[ $# -ne 1 ]]; then
    print_help
    exit 1
fi

if [[ "$1" == "-h" ]]; then
    print_help
    exit 0
fi

root=$1
if [[ ! -d "$root" ]]; then
    echo "ERROR: '$root' is not a directory"
    print_help
    exit 1
fi

echo "Checking all \$_cli_image_digest values are consistent under ${root}"
echo "---------"

digest_files=()
digest_values=()

while IFS= read -r f; do
    v=$(sed -En 's/.*\$_cli_image_digest[[:space:]]*:=[[:space:]]*"([^:]+:[^"]+)".*/\1/p' "$f" | head -1)
    if [[ -n "$v" ]]; then
        digest_files+=("$f")
        digest_values+=("$v")
    fi
done < <(grep -Erl --include '*.yaml' --include '*.yml' --include '*.tpl' 'quay.io/ibmmas/cli' "$root")

distinct_digests=$(printf '%s\n' "${digest_values[@]}" | sort -u)
distinct_count=$(printf '%s\n' "${distinct_digests}" | grep -c .)

if [[ $distinct_count -gt 1 ]]; then
    echo ""
    echo "ERROR: Inconsistent \$_cli_image_digest values found across template files:"
    echo "  The following distinct digest values were seen:"
    while IFS= read -r d; do
        echo "    $d"
    done <<< "$distinct_digests"
    echo "  Per-file breakdown:"
    for i in "${!digest_files[@]}"; do
        echo "    ${digest_values[$i]}  ${digest_files[$i]}"
    done | sort
    echo ""
    exit 1
fi

echo "All ${#digest_files[@]} file(s) use the same \$_cli_image_digest: ${distinct_digests}"
