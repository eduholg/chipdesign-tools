#!/bin/bash

set -ex
cd /tmp

# Build yosys
# -----------

REPO_COMMIT_SHORT="$YOSYS_REPO_COMMIT"
YOSYS_PREFIX="${TOOLS}/${YOSYS_NAME}/${REPO_COMMIT_SHORT}"

# Configure git for better network reliability
git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# Clone main repo first, then submodules separately for better retry control
git clone --depth=1 -b "${YOSYS_REPO_COMMIT}" "${YOSYS_REPO_URL}" "${YOSYS_NAME}"
cd "${YOSYS_NAME}"
# Initialize and update submodules with retries
set +e
for i in {1..3}; do
    if git submodule update --init --recursive --depth=1; then
        break
    else
        if [ $i -lt 3 ]; then
            echo "Submodule clone failed, retrying in 5 seconds..."
            sleep 5
        else
            echo "Submodule clone failed after 3 attempts"
            set -e
            exit 1
        fi
    fi
done
set -e
# Use limited parallelism to reduce RAM usage
BUILD_JOBS=${MAX_BUILD_JOBS:-2}
echo "Building yosys with $BUILD_JOBS parallel jobs"
make install -j"${BUILD_JOBS}" PREFIX="${YOSYS_PREFIX}" CONFIG=gcc ABC_ARCHFLAGS=-Wno-register
cd ..

export PATH=$PATH:${TOOLS}/${YOSYS_NAME}/${REPO_COMMIT_SHORT}/bin

# Build yosys eqy
# ---------------

git clone --depth=1 -b "${YOSYS_REPO_COMMIT}" ${YOSYS_EQY_REPO_URL} ${YOSYS_EQY_NAME}
cd ${YOSYS_EQY_NAME}
# Initialize submodules with retries
set +e
for i in {1..3}; do
    if git submodule update --init --recursive --depth=1; then
        break
    else
        if [ $i -lt 3 ]; then
            echo "Submodule clone failed, retrying in 5 seconds..."
            sleep 5
        else
            echo "Submodule clone failed after 3 attempts"
            set -e
            exit 1
        fi
    fi
done
set -e
sed -i "s#^PREFIX.*#PREFIX=${YOSYS_PREFIX}#g" Makefile
echo "Building yosys eqy with $BUILD_JOBS parallel jobs"
make install -j"${BUILD_JOBS}"
cd ..

# Build yosys sby
# ---------------

git clone --depth=1 -b "${YOSYS_REPO_COMMIT}" ${YOSYS_SBY_REPO_URL} ${YOSYS_SBY_NAME}
cd ${YOSYS_SBY_NAME}
# Initialize submodules with retries
set +e
for i in {1..3}; do
    if git submodule update --init --recursive --depth=1; then
        break
    else
        if [ $i -lt 3 ]; then
            echo "Submodule clone failed, retrying in 5 seconds..."
            sleep 5
        else
            echo "Submodule clone failed after 3 attempts"
            set -e
            exit 1
        fi
    fi
done
set -e
sed -i "s#^PREFIX.*#PREFIX=${YOSYS_PREFIX}#g" Makefile
echo "Building yosys sby with $BUILD_JOBS parallel jobs"
make install -j"${BUILD_JOBS}" 
cd ..

# Install yosys mcy
# -----------------

# git clone --depth=1 -b "${YOSYS_REPO_COMMIT}" --recurse ${YOSYS_MCY_REPO_URL} ${YOSYS_MCY_NAME}
# cd ${YOSYS_MCY_NAME}
# sed -i "s#^PREFIX.*#PREFIX=${YOSYS_PREFIX}#g" Makefile
# make install -j"$(nproc)"
# cd ..

# Cleanup: Remove all source repositories
cd /tmp
rm -rf "${YOSYS_NAME}" "${YOSYS_EQY_NAME}" "${YOSYS_SBY_NAME}" "${YOSYS_MCY_NAME}"