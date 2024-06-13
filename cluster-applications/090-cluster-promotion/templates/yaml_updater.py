#!/usr/bin/env python3
# Licensed Materials - Property of IBM
# 5737-M66, 5900-AAA
# (C) Copyright IBM Corp. 2024 All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication, or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.

import argparse
import collections.abc
import os
import yaml

def _merge_dict(dct, merge_dct):
    for k, _ in merge_dct.items():
        if (
            k in dct
            and isinstance(dct[k], dict)
            and isinstance(merge_dct[k], collections.abc.Mapping)
        ):
            return _merge_dict(dct[k], merge_dct[k])
        else:
            if k in dct:
                dct[k] = merge_dct[k]
                return True

def update_yaml(path, key_value_yaml):
    """Update a YAML file with new values.

    Args:
        path (str): The path to the YAML file.
        key_value (dict): A dictionary containing the keys and values to be updated.

    Returns:
        None
    """
    key_value = yaml.safe_load(key_value_yaml)

    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith(".yaml"):
                full_path = os.path.join(root, file)
                with open(full_path, "r") as file:
                    data = yaml.safe_load(file)
                updated = _merge_dict(data, key_value)
                if updated:
                    print(f"Updated {full_path}")
                    with open(full_path, "w") as file:
                        yaml.dump(data, file, sort_keys=False, explicit_start=True, line_break=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    # Primary Options
    parser.add_argument("--path", required=True, help="Path to yaml files to update")
    parser.add_argument("--valuesYaml", required=True, help="Comma seperated list of yaml entries that need updating in the path")
    args, unknown = parser.parse_known_args()
    
    path = args.path
    key_values_yaml = args.valuesYaml
    split_key_values_yaml = key_values_yaml.split(",")
    for key_values in split_key_values_yaml:
        update_yaml(path, key_values)
    
