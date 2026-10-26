"""Check test inventory and exact normalized body duplicates, not semantic coverage."""
import collections
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cases = []
for path in sorted((root / "tests/play").glob("test_*.gd")):
    source = path.read_text(encoding="utf-8-sig")
    matches = list(re.finditer(r"(?m)^func ([A-Za-z0-9_]+)\([^\n]*", source))
    for index, match in enumerate(matches):
        name = match.group(1)
        if not name.startswith("test_"):
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else len(source)
        body = source[match.end():end]
        # Ignore blank lines and standalone comments, preserve strings and values.
        normalized = "\n".join(line.strip() for line in body.splitlines()
                               if line.strip() and not line.lstrip().startswith("#"))
        cases.append({"name": name, "file": path.relative_to(root).as_posix(),
                      "body_sha256": hashlib.sha256(normalized.encode()).hexdigest()})

def duplicates(key):
    groups = collections.defaultdict(list)
    for case in cases:
        groups[case[key]].append(case["name"] + " @ " + case["file"])
    return [items for items in groups.values() if len(items) > 1]

report = {"test_count": len(cases), "duplicate_names": duplicates("name"),
          "identical_normalized_bodies": duplicates("body_sha256"), "cases": cases,
          "limitation": "Exact textual duplication only; this does not measure semantic coverage."}
output = root / "test-results/player-flow/test-audit.json"
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Tests: {len(cases)}; duplicate names: {len(report['duplicate_names'])}; identical bodies: {len(report['identical_normalized_bodies'])}")
print(output)
