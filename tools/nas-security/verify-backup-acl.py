#!/usr/bin/python3
"""Read ACL metadata for a backup subtree. Never alter ACLs or open backups."""

import argparse
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


BACKUP_ROOT = "/volume1/homes/kraktoos/Backups/rgo-vps"
ACL_TOOL = "/usr/syno/bin/synoacltool"
ENTRY = re.compile(
    r"^\s*\[\d+\] ([a-z_]+):([^:]*):(allow|deny):([rwxpdDaARWcCo-]{13}):"
    r"([fdin-]{4}) \(level:\d+\)\s*$"
)
ALLOWED = {("user", "kraktoos"), ("user", "root"), ("group", "administrators")}


def check_acl(text, *, is_root):
    problems = []
    entries = []
    archive = None
    if not re.search(r"^ACL version: \d+\s*$", text, re.MULTILINE):
        return ["unrecognized ACL output"]
    for line in text.splitlines():
        if line.startswith("Archive:"):
            archive = {part.strip() for part in line.partition(":")[2].split(",")}
        if line.lstrip().startswith("["):
            match = ENTRY.fullmatch(line)
            if not match:
                problems.append("unrecognized ACL entry")
                continue
            kind, principal, action, rights, _ = match.groups()
            entries.append((kind, principal, action, rights))
            if action == "allow" and (kind, principal) not in ALLOWED:
                problems.append("unexpected allow principal " + kind + ":" + principal)
            if action == "deny":
                problems.append("deny entry requires effective access review for " + kind + ":" + principal)
    if archive is None:
        problems.append("missing archive flags")
    elif is_root and "is_inherit" in archive:
        problems.append("backup root still inherits its parent ACL")
    if not any(
        kind == "user" and principal == "kraktoos" and action == "allow"
        and rights == "rwxpdDaARWcCo"
        for kind, principal, action, rights in entries
    ):
        problems.append("missing full backup-account allow entry")
    if not any(
        kind == "group" and principal == "administrators" and action == "allow"
        and set("rwxpdDaARWc").issubset(rights)
        for kind, principal, action, rights in entries
    ):
        problems.append("missing administrator recovery entry")
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=BACKUP_ROOT)
    args = parser.parse_args(argv)
    root = Path(args.root).absolute()
    if root.is_symlink() or not root.is_dir():
        parser.error("backup root must be an existing directory, not a symlink")
    checked = 0
    failures = 0
    details = []
    try:
        # Enumerate metadata only and refuse links or special files. Bound the
        # walk so unexpected tree growth cannot turn this into an endless job.
        def walk_error(error):
            raise error

        for current, directories, files in os.walk(root, followlinks=False, onerror=walk_error):
            paths = [Path(current)] + [Path(current) / name for name in files]
            paths += [Path(current) / name for name in directories if (Path(current) / name).is_symlink()]
            for path in paths:
                checked += 1
                if checked > 10000:
                    raise RuntimeError("more than 10,000 paths, review tree growth before retrying")
                mode = path.lstat().st_mode
                if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
                    problems = ["symlink or special file, not inspected"]
                else:
                    result = subprocess.run(
                        [ACL_TOOL, "-get", str(path)], capture_output=True,
                        text=True, timeout=10, check=False,
                    )
                    problems = (
                        ["synoacltool failed, privileges or path need review"]
                        if result.returncode else check_acl(result.stdout, is_root=path == root)
                    )
                if problems:
                    failures += 1
                    if len(details) < 12:
                        details.append((str(path.relative_to(root)) or ".", problems))
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("INCOMPLETE: " + str(error), file=sys.stderr)
        return 2
    for path, problems in details:
        print(path + ": " + "; ".join(problems))
    print("ACL metadata: %d paths checked, %d paths require review" % (checked, failures))
    print("Effective access, parent deletion rights, freshness and backup contents were not tested.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
