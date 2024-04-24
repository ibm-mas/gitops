#/bin/bash

echo "build/bin/copy-gitops.sh -s <source ibm-mas/gitops directory> -t <target ibm-mas/gitops directory> "
echo ""
echo "Example usage: "
echo "  build/bin/copy-gitops.sh -s /Users/whitfiea/Work/Git/ibm-mas/gitops -t /Users/whitfiea/Work/Git/ibm-mas/mas-gitops"
echo ""

# Process command line arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    shift
    case $key in
        -s|--source)
        SOURCE=$1
        shift
        ;;

        -t|--target)
        TARGET=$1
        shift
        ;;

        *)
        # unknown option
        echo -e "\nUsage Error: Unsupported flag \"${key}\"\n\n"
        exit 1
        ;;
    esac
done

: ${SOURCE?"Need to set -s|--source argument for source directory"}
: ${TARGET?"Need to set -t|--target argument for target directory"}

echo "Deleting all files in target"
rm -rf ${TARGET}/*

echo "Copying gitops"
cp -vr ${SOURCE}/* ${TARGET}
