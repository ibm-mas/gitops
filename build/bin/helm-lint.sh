#!/bin/bash

# echo "build/bin/helm-lint.sh -p <chart_path>"
# echo ""
# echo "Example usage: "
# echo "  build/bin/helm-lint.sh -p ../../instance-applications/000-ibm-sync-resources"
# echo ""

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

# Check if the chart_path exists
if [ ! -d "$CHART_PATH" ]; then
    echo "Error: Chart path $CHART_PATH does not exist."
    exit 1
fi

helm build update

echo "--------"
echo "Linting chart $CHART_PATH using Helm lint"
helm lint "$CHART_PATH" || exit 1

echo "--------"
echo "Templating chart $CHART_PATH using Helm template"
helm template "$CHART_PATH" || exit 1
