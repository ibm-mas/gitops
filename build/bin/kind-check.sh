#!/bin/bash

echo "build/bin/kind-check.sh -p <chart_path>"
echo ""
echo "Example usage: "
echo "  build/bin/kind-check.sh -p ../../instance-applications/000-ibm-sync-resources"
echo ""

# Process command line arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -p|--chart-path)
        CHART_PATH=$1
        shift
        ;;

        *)
        # unknown option
        echo -e "\nUsage Error: Unsupported flag \"${key}\"\n\n"
        exit 1
        ;;
    esac
done

: ${CHART_PATH?"Need to set -p|--chart_path argument for chart path"}

# Check if the Helm chart has any namespaces defined
function check_namespace() {
  echo "- Searching for templates using kind: Namespace"
  echo " "

  # Check if there are any namespaces defined in the Helm chart
  if grep --recursive -e "kind: Namespace" $1; then
    echo "- Error: Found namespaces in Helm chart."
    exit 1
  else
    echo "- Success: No namespaces found in Helm chart."
  fi
}

# Check if the chart_path exists
if [ ! -d "$CHART_PATH" ]; then
    echo "Error: Chart path $CHART_PATH does not exist."
    exit 1
fi

echo "--------"
echo "Checking chart doesn't contain unexpected kinds"
check_namespace "$CHART_PATH" || exit 1
