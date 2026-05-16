Build the final ad-hoc signed ZIP for distribution.

First run the full release gate (tests + build):
```bash
cd /Users/zinklee/Code/timer-app-for-my-gf && bash scripts/run_xcode_release_gate.sh 2>&1 | tail -20
```

If that passes, package it:
```bash
cd /Users/zinklee/Code/timer-app-for-my-gf && bash scripts/package_xcode_unsigned.sh 2>&1 | tail -20
```

Report the ZIP path and file size. The output ZIP goes to `.build/xcode/CozyTime-unsigned-xcode.zip`.
