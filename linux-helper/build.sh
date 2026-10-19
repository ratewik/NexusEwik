#!/bin/sh
# NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
# Builds bin/nexusewik-linuxhelper. Needs gcc and the X11 dev packages:
#   sudo apt install build-essential libx11-dev libxi-dev libxtst-dev libxrandr-dev libxfixes-dev
set -e
cd "$(dirname "$0")"
mkdir -p bin
gcc -O2 -Wall -Wextra -std=gnu11 src/*.c -o bin/nexusewik-linuxhelper -lX11 -lXi -lXtst -lXrandr -lXfixes -lm
echo "built bin/nexusewik-linuxhelper"
