Run a full visual and code quality audit of the app.

1. Run design lint:
```bash
bash /Users/zinklee/Code/timer-app-for-my-gf/scripts/lint_design.sh 2>&1
```

2. Run swift build:
```bash
cd /Users/zinklee/Code/timer-app-for-my-gf && swift build 2>&1 | grep -E 'error:|warning:' | head -20
```

3. Run tests:
```bash
cd /Users/zinklee/Code/timer-app-for-my-gf && swift test 2>&1 | tail -10
```

4. Check for any remaining TODO comments that were left in source:
```bash
grep -rn "TODO\|FIXME\|HACK" /Users/zinklee/Code/timer-app-for-my-gf/Sources/CozyTime/ | head -20
```

Report a summary: lint violations count, build status, test pass rate, and top TODOs.
