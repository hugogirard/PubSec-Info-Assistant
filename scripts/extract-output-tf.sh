# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

#!/bin/bash
set -e

printInfo "Writing terraform output to inf_output.json"
sudo terraform output -json > inf_output.json