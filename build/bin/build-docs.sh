#!/bin/bash

python -m pip install -q mkdocs mkdocs-redirects
mkdocs build --verbose --clean

# TODO: add back --strict
