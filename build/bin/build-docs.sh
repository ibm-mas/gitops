#!/bin/bash

python -m pip install -q mkdocs mkdocs-redirects
python -m pip install -q mkdocs mkdocs-macros-plugin
mkdocs build --verbose --clean

# TODO: add back --strict
