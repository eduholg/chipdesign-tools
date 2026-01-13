#!/bin/bash

set -ex
cd /tmp

# Configure git for better network reliability
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# Clone with shallow depth first to reduce download size and improve reliability
# Use retry logic for network reliability
set +e
for i in {1..5}; do
    # Try shallow clone with reasonable depth (500 commits should be enough for recent commits)
    if git clone --branch dev --depth 500 "$IHP_PDK_REPO_URL" ihp; then
        cd ihp
        set +e
        # Check if the commit is available in the shallow clone
        if git cat-file -e "$IHP_PDK_REPO_COMMIT" 2>/dev/null; then
            set -e
            git checkout $IHP_PDK_REPO_COMMIT
            break
        else
            # Commit not in shallow clone, fetch more history
            set -e
            echo "Commit not found in shallow clone, fetching more history..."
            git fetch --unshallow || git fetch --depth=2000
            git checkout $IHP_PDK_REPO_COMMIT
            break
        fi
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

# Ensure we're in the ihp directory
# When we break from the loop after successful clone, we're in /tmp/ihp
# But if the loop completed without success (shouldn't happen due to exit 1), we'd be in /tmp
# So we need to check our current location and navigate accordingly
if [ -d "/tmp/ihp" ]; then
    cd /tmp/ihp
elif [ -d "ihp" ]; then
    cd ihp
else
    echo "Error: ihp directory not found after clone"
    exit 1
fi

# Initialize submodules with retries
set +e
for i in {1..3}; do
    if git submodule update --init --recursive; then
        set -e
        break
    else
        if [ $i -lt 3 ]; then
            echo "Submodule update failed, retrying in 5 seconds..."
            sleep 5
        else
            echo "Submodule update failed after 3 attempts"
            set -e
            exit 1
        fi
    fi
done
set -e

rm -rf \
    ihp-sg13g2/libs.doc/meas \
    ihp-sg13g2/libs.tech/klayout/tech/lvs/testing \
    ihp-sg13g2/libs.tech/openems/testcase

# Some modifications/cleanup needed of stock IHP PDK
# 1) Remove the `pre_osdi` line from the examples
find . -name "*.sch" -exec sed -i '/pre_osdi/d' {} \;

mkdir -p "$PDK_ROOT"
mv ihp-sg13g2 "$PDK_ROOT/$IHP_PDK_NAME"

# Compile the PSP model (DO NOT COMPILE THEM HERE!)
# cd "$PDK_ROOT/$IHP_PDK_NAME/libs.tech/ngspice/openvaf"
# OPENVAF_VERSION=$(ls "$TOOLS/$OPENVAF_NAME")
# openvaf psp103_nqs.va

# Cleanup: Remove source repository after moving PDK
cd /tmp
rm -rf ihp
