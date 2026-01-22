#!/bin/bash

set -ex

export KLAYOUT_HOME=$PDK_ROOT/ihp-sg13g2/libs.tech/klayout
DRC_SCRIPT=$KLAYOUT_HOME/tech/drc/sg13g2_maximal.lydrc

# Fix KLayout DRC script compatibility with newer KLayout versions
# The script needs to explicitly load the layout before using 'source'
if [ -f "$DRC_SCRIPT" ]; then
    # Check if the script already has the layout loading fix
    if ! grep -q "# Load layout explicitly" "$DRC_SCRIPT"; then
        # Create a backup
        cp "$DRC_SCRIPT" "$DRC_SCRIPT.bak"
        
        # Add layout loading at the very beginning of the script
        # The input file is passed via -rd input=... parameter
        # We need to load it before any 'source' commands are used
        # This fixes compatibility with KLayout 0.30+ which requires explicit layout loading
        {
            echo "# Load layout explicitly (required for newer KLayout versions)"
            echo "# This fix is needed for KLayout 0.30+ compatibility"
            echo "# The input variable is set via -rd input=... command line parameter"
            echo "if \$input != nil && \$input != \"\""
            echo "  source(\$input)"
            echo "end"
            echo ""
            cat "$DRC_SCRIPT.bak"
        } > "$DRC_SCRIPT.tmp" && mv "$DRC_SCRIPT.tmp" "$DRC_SCRIPT"
        
        echo "Patched $DRC_SCRIPT for KLayout compatibility"
    else
        echo "$DRC_SCRIPT already patched"
    fi
else
    echo "Warning: DRC script not found at $DRC_SCRIPT"
fi
