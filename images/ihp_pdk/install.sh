#!/bin/bash

set -ex
cd /tmp

IHP_PDK_REPO_BRANCH="${IHP_PDK_REPO_BRANCH:-v0.3.0}"

git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

set +e
for i in {1..5}; do
    if git clone --branch "$IHP_PDK_REPO_BRANCH" --depth 1 --recurse-submodules "$IHP_PDK_REPO_URL" ihp; then
        break
    else
        if [ $i -lt 5 ]; then
            echo "Git clone failed, retrying in 15 seconds... (attempt $i/5)"
            sleep 15
            rm -rf ihp 2>/dev/null || true
        else
            echo "Git clone failed after 5 attempts"
            set -e
            exit 1
        fi
    fi
done
set -e

cd /tmp/ihp

rm -rf \
    ihp-sg13g2/libs.doc/meas \
    ihp-sg13g2/libs.tech/klayout/tech/lvs/testing \
    ihp-sg13g2/libs.tech/openems/testcase

find . -name "*.sch" -exec sed -i '/pre_osdi/d' {} \;

mkdir -p "$PDK_ROOT"
mv ihp-sg13g2 "$PDK_ROOT/$IHP_PDK_NAME"

# Compile Verilog-A models using openvaf (v0.3.0+ structure)
cd "$PDK_ROOT/$IHP_PDK_NAME/libs.tech/verilog-a"
bash openvaf-compile-va.sh

cd /tmp
rm -rf ihp
