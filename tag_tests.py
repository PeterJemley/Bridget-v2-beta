#!/usr/bin/env python3
import argparse, json, os, re, subprocess, sys, plistlib, binascii
from collections import defaultdict

# ---------------- Status precedence ----------------
def get_status_priority(status: str) -> int:
    priority = {
        "Failure": 4,
        "Expected Failure": 3,
        "Success": 2,
        "Skipped": 1,
        "Unknown": 0
    }
    return priority.get(status, 0)

def worsen(old_status, new_status):
    if old_status is None:
        return new_status
    return new_status if get_status_priority(new_status) > get_status_priority(old_status) else old_status

# ---------------- xcresult helpers ----------------
def sh(*args):
    return subprocess.check_output(args, stderr=subprocess.DEVNULL)

def xcget(bundle_path):
    return json.loads(sh("xcrun", "xcresulttool", "get", "--legacy", "--path", bundle_path, "--format", "json"))

def xcget_id(bundle_path, _id):
    return json.loads(sh("xcrun", "xcresulttool", "get", "--legacy", "--path", bundle_path, "--id", _id, "--format", "json"))

def collect_tests(obj, out):
    """Depth-first walk to collect (identifier, testStatus)."""
    if isinstance(obj, dict):
        if "testStatus" in obj and "identifier" in obj:
            # Handle nested structure
            identifier = obj["identifier"]
            test_status = obj["testStatus"]
            if isinstance(identifier, dict) and "_value" in identifier:
                identifier = identifier["_value"]
            if isinstance(test_status, dict) and "_value" in test_status:
                test_status = test_status["_value"]
            out.append((identifier, test_status))
        for v in obj.values():
            collect_tests(v, out)
    elif isinstance(obj, list):
        for v in obj:
            collect_tests(v, out)

def parse_identifier(identifier):
    """
    Typical forms:
      - "MyModule.MySuite/testFoo()"
      - "MySuite/testFoo()"
      - "LoginTests/testX()"
      - "testFoo()"
    Returns (suite_token or None, function_name or None)
    """
    # Handle nested identifier structure
    if isinstance(identifier, dict) and "_value" in identifier:
        identifier = identifier["_value"]
    
    if not isinstance(identifier, str):
        return None, None
        
    left, sep, right = identifier.partition("/")
    func = right.split("(")[0] if sep else None
    suite = left.split(".")[-1] if left else None
    if not sep and left:
        maybe_func = left.split("(")[0]
        if maybe_func and maybe_func != left:
            func = maybe_func
            suite = None
    return suite, func

# ---------------- Source scanning (Swift Testing + XCTest) ----------------
SUITE_PAT = re.compile(
    r'@Suite\b[^\n]*?(?:\n\s*)?'
    r'(?:final\s+|public\s+|open\s+|internal\s+|fileprivate\s+|private\s+)?'
    r'(?:class|struct|enum|actor)\s+([A-Za-z_]\w*)\b',
    re.M
)
TEST_FUNC_PAT = re.compile(
    r'@Test\b[^\n]*?(?:\n\s*)?'
    r'(?:final\s+|public\s+|open\s+|internal\s+|fileprivate\s+|private\s+)?'
    r'func\s+([A-Za-z_]\w*)\s*\(',
    re.M
)
XCTESTCASE_PAT = re.compile(
    r'^\s*(?:final\s+|public\s+|open\s+|internal\s+|fileprivate\s+|private\s+)?'
    r'class\s+([A-Za-z_]\w*)\s*:\s*XCTestCase\b',
    re.M
)

def read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except Exception:
        return ""

def discover_suites(src: str):
    """Swift Testing @Suite types (preferred mapping)."""
    return SUITE_PAT.findall(src)

def discover_xctest_classes(src: str):
    """XCTestCase subclasses."""
    return XCTESTCASE_PAT.findall(src)

def discover_top_level_tests(src: str):
    """
    Fallback for files without suites/classes:
    capture @Test funcs (best-effort; may also catch methods inside types).
    We only use this when NO suites/classes were found in the file.
    """
    return TEST_FUNC_PAT.findall(src)

def is_test_file(dirpath, filename):
    if not filename.endswith(".swift"):
        return False
    parts = set(dirpath.split(os.sep))
    if any(p.endswith("Tests") for p in parts):
        return True
    if filename.endswith(("Tests.swift", "UITests.swift")):
        return True
    return False

# ---------------- Finder tagging ----------------
def read_existing_tags(path: str):
    try:
        data = sh("xattr", "-p", "com.apple.metadata:_kMDItemUserTags", path)
        return plistlib.loads(data)
    except subprocess.CalledProcessError:
        return []
    except Exception:
        return []

def write_tags(path: str, tags):
    tags = list(dict.fromkeys(tags))
    blob = plistlib.dumps(tags)
    hexdata = binascii.hexlify(blob).decode("ascii")
    subprocess.call(["xattr", "-wx", "com.apple.metadata:_kMDItemUserTags", hexdata, path],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def add_tag(path: str, tag: str):
    existing = read_existing_tags(path)
    if tag not in existing:
        existing.append(tag)
    write_tags(path, existing)

# ---------------- Classification ----------------
def classify_status(statuses):
    """Map a set of raw statuses to file-level tag."""
    if any(s == "Failure" for s in statuses):
        return "Failed"
    if any(s in ("Success", "Expected Failure") for s in statuses):
        return "Passed"
    if any(s == "Skipped" for s in statuses):
        return "Unknown"
    return "Unknown"

# ---------------- Main ----------------
def main():
    ap = argparse.ArgumentParser(
        description="Tag Swift test files (Swift Testing @Suite/@Test and XCTest) based on .xcresult statuses."
    )
    ap.add_argument("xcresult", help="Path to .xcresult bundle (e.g., DerivedData/.../TestRun.xcresult)")
    ap.add_argument("--root", default=".", help="Project root to search (default: .)")
    ap.add_argument("--dry-run", action="store_true", help="Preview actions; do not write Finder tags")
    ap.add_argument("--passed-tag", default="TestPassed")
    ap.add_argument("--failed-tag", default="TestFailed")
    ap.add_argument("--unknown-tag", default="TestUnknown")
    args = ap.parse_args()

    bundle = os.path.abspath(args.xcresult)
    root = os.path.abspath(args.root)

    # Load .xcresult
    try:
        root_json = xcget(bundle)
    except subprocess.CalledProcessError:
        print("error: couldn't read the .xcresult bundle. Confirm path or build with -resultBundlePath.", file=sys.stderr)
        sys.exit(1)

    # Collect testsRef
    test_ref_ids = []
    for action in root_json.get("actions", {}).get("_values", []):
        tests_ref = action.get("actionResult", {}).get("testsRef")
        if isinstance(tests_ref, dict) and "id" in tests_ref:
            test_id = tests_ref["id"]
            if isinstance(test_id, dict) and "_value" in test_id:
                test_ref_ids.append(test_id["_value"])
            elif isinstance(test_id, str):
                test_ref_ids.append(test_id)
    if not test_ref_ids:
        print("No test results found in the bundle (no testsRef).", file=sys.stderr)
        sys.exit(2)

    # Gather all leaf tests (identifier, status)
    tests = []
    for _id in test_ref_ids:
        tjson = xcget_id(bundle, _id)
        collect_tests(tjson, tests)
    if not tests:
        print("Found a test plan but no test nodes with status; nothing to tag.", file=sys.stderr)
        sys.exit(3)

    # Reduce worst status per suite and per function
    by_suite = {}     # "SuiteOrClassName" -> worst status
    by_func  = {}     # "testFunction"     -> worst status
    for ident, status in tests:
        suite, func = parse_identifier(ident)
        if suite:
            by_suite[suite] = worsen(by_suite.get(suite), status)
        if func:
            by_func[func] = worsen(by_func.get(func), status)

    # Index test files & extract names
    file_infos = []   # list of dicts: {path, suites, xctest_classes, top_level_funcs}
    func_to_files = defaultdict(set)

    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            if not is_test_file(dirpath, fn):
                continue
            path = os.path.join(dirpath, fn)
            src  = read_text(path)
            suites = discover_suites(src)
            classes = discover_xctest_classes(src)

            # Strategy: prefer suites/classes; only if none, look for top-level @Test funcs
            if suites or classes:
                funcs = []  # not used for mapping when suites/classes exist
            else:
                funcs = discover_top_level_tests(src)
                for f in funcs:
                    func_to_files[f].add(path)

            file_infos.append({
                "path": path,
                "suites": suites,
                "xctest_classes": classes,
                "top_level_funcs": funcs
            })

    if not file_infos:
        print(f"No test .swift files found under {root}", file=sys.stderr)
        sys.exit(4)

    # Decide status per file
    summary = {"Failed": 0, "Passed": 0, "Unknown": 0}

    for info in file_infos:
        path = info["path"]
        suites = info["suites"]
        classes = info["xctest_classes"]
        funcs = info["top_level_funcs"]

        collected_statuses = set()
        strategy = "none"

        # 1) Prefer @Suite (Swift Testing) and XCTest classes
        tokens = []
        if suites:
            strategy = "suite"
            tokens.extend(suites)
        if classes:
            strategy = "xctest" if strategy == "none" else strategy + "+xctest"
            tokens.extend(classes)

        for t in tokens:
            if t in by_suite:
                collected_statuses.add(by_suite[t])

        # 2) Fallback: top-level @Test functions (collision-aware)
        if not collected_statuses and funcs:
            # Detect collision: if any function name appears in >1 files, mark unknown
            collision = any(len(func_to_files[f]) > 1 for f in funcs)
            if collision:
                strategy = "func-collision"
                file_tag_kind = "Unknown"
                tag_name = args.unknown_tag
                if args.dry_run:
                    print(f"{file_tag_kind:7}  {path}   [strategy={strategy}; funcs={', '.join(funcs)}]")
                else:
                    add_tag(path, tag_name)
                    print(f"Tagged {os.path.relpath(path, root)} -> {tag_name}   [strategy={strategy}]")
                summary[file_tag_kind] += 1
                continue
            else:
                strategy = "func-unique"
                for f in funcs:
                    if f in by_func:
                        collected_statuses.add(by_func[f])

        # 3) Classify & tag
        file_tag_kind = classify_status(collected_statuses) if collected_statuses else "Unknown"
        summary[file_tag_kind] += 1

        tag_name = {
            "Failed": args.failed_tag,
            "Passed": args.passed_tag,
            "Unknown": args.unknown_tag
        }[file_tag_kind]

        if args.dry_run:
            used = suites or classes or funcs
            used_str = ', '.join(used) if used else ''
            print(f"{file_tag_kind:7}  {path}   [strategy={strategy}; tokens={used_str}]")
        else:
            add_tag(path, tag_name)
            print(f"Tagged {os.path.relpath(path, root)} -> {tag_name}   [strategy={strategy}]")

    print("\nSummary:")
    for k in ("Failed", "Passed", "Unknown"):
        print(f"  {k:7}: {summary[k]}")

if __name__ == "__main__":
    main()
