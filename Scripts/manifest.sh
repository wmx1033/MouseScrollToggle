#!/bin/zsh
# Ordered, explicit input set. Hashes use relative names, independent of checkout path.
bundle_files=(VERSION Sources/MouseScrollToggle.swift Scripts/common.sh Scripts/runtime.sh Scripts/doctor.sh Scripts/manifest.sh Scripts/installer.sh Scripts/install.sh Scripts/control.sh Scripts/uninstall.sh Scripts/click.sh)
bundle_hash() ( cd "$root"; shasum -a 256 $bundle_files | shasum -a 256 | cut -d ' ' -f1 )
