#!/bin/bash

set -ex

pip install uv

# Increase timeout for large package downloads
export UV_HTTP_TIMEOUT=300

uv pip install --system --strict --compile-bytecode \
    "numpy<2" \
    gdsfactory \
    glayout \
    cace \
    pandas \
    ojson \
    networkx \
    pytest \
    scipy \
    gdstk \
    svgutils \
    prettyprinttree \
    pyspice \
    volare==0.18.1 \
    spyci \
    jupyter \
    jupyterlab \
    ipython \
    ipykernel \
    ipywidgets \
    docopt \
    klayout \
    pygmid \
    kfactory \
    ruff \
    click \
    "pygobject<3.52.0" \
    xdot

# Cleanup: Remove Python cache files
find /usr/local -name "*.pyc" -delete 2>/dev/null || true
find /usr/local -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find ~/.cache -type f -delete 2>/dev/null || true
rm -rf ~/.cache/pip ~/.cache/uv 2>/dev/null || true