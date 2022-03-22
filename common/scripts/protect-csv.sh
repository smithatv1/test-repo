#!/bin/bash
#
# Copyright 2020 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


function msg() {
    printf '%b\n' "$1"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function protect_csv() {
    csv=$1
    channel=$2
    operator_name=$3

    if [ -z "${csv}" ]; then
        error "No CSV defined for ${channel} channel"
    fi

    csv_version=${csv//${operator_name}.v/}
    # check unstaged changes
    for file in $(git diff --name-only); do
        if [[ "${file}" =~ ^deploy/olm-catalog/${operator_name}/${csv_version}/.* ]]; then
            error "Protected channel resource cannot be modified: ${file}"
        fi
    done

    # check staged changes
    for file in $(git diff --name-only --cached); do
        if [[ "${file}" =~ ^deploy/olm-catalog/${operator_name}/${csv_version}/.* ]]; then
            error "Protected channel resource cannot be modified: ${file}"
        fi
    done
}

if [ ! -f "$(command -v yq 2> /dev/null)" ]; then
    error "yq command not found"
fi

DEPLOY_DIR=${DEPLOY_DIR:-deploy}
OPERATOR_NAME=$(basename "$(find "${DEPLOY_DIR}/olm-catalog" -type d -maxdepth 1 | tail -1 )")
PACKAGE_FILE=$(find "${DEPLOY_DIR}" -name '*.package.yaml' | head -1)

if [ ! -f "${PACKAGE_FILE}" ]; then
    error "Missing package yaml file"
fi

# protect stable-v1 channel
STABLE_CSV=$(yq r "${PACKAGE_FILE}" "channels.(name==stable-v1).currentCSV")
echo "protect-csv ${OPERATOR_NAME} stable-v1 ${STABLE_CSV}"
protect_csv "${STABLE_CSV}" "stable-v1" "${OPERATOR_NAME}"

# protect beta channel
BETA_CSV=$(yq r "${PACKAGE_FILE}" "channels.(name==beta).currentCSV")
echo "protect-csv ${OPERATOR_NAME} beta ${BETA_CSV}"
protect_csv "${BETA_CSV}" "beta" "${OPERATOR_NAME}"