#!/usr/bin/env sh
set -eu
rm -rf build xsim.dir xvlog.log xvlog.pb xelab.log xelab.pb xsim.log xsim.jou .Xil xsim_*.backup.log xsim_*.backup.jou
find tools model -type d -name __pycache__ -prune -exec rm -rf {} +
