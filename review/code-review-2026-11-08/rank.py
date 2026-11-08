import sys, xml.etree.ElementTree as ET
from collections import defaultdict
root = ET.parse(sys.argv[1]).getroot()
files = defaultdict(float); counts = defaultdict(int); tests = []
for suite in root.iter('testsuite'):
    for tc in suite.iter('testcase'):
        t = float(tc.get('time', 0)); f = tc.get('classname') or suite.get('name')
        files[f] += t; counts[f] += 1; tests.append((t, f, tc.get('name')))
total = sum(files.values())
print(f"total test time {total:.1f}s over {len(tests)} tests in {len(files)} files")
print("\n== top 25 files ==")
for f, t in sorted(files.items(), key=lambda x: -x[1])[:25]:
    print(f"{t:7.2f}s {counts[f]:4d} tests  {f}")
print("\n== top 20 tests ==")
for t, f, n in sorted(tests, reverse=True)[:20]:
    print(f"{t:7.2f}s  {f} :: {n}")
print("\n== cumulative ==")
acc = 0
for i, (f, t) in enumerate(sorted(files.items(), key=lambda x: -x[1]), 1):
    acc += t
    if i in (5, 10, 20, 40, 80): print(f"top {i} files = {acc:.1f}s ({100*acc/total:.0f}%)")
