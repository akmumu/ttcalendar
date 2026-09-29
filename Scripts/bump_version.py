#!/usr/bin/env python3
"""Update the app and widget versions together; never reuse an existing build."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 3 or not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", sys.argv[1]) or not sys.argv[2].isdigit():
    sys.exit("Usage: python3 Scripts/bump_version.py 1.26 26")
version, build = sys.argv[1:]
project = Path(__file__).resolve().parent.parent / "ttcalendar.xcodeproj/project.pbxproj"
text = project.read_text()
versions = re.findall(r"MARKETING_VERSION = ([\d.]+);", text)
builds = re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", text)
if len(versions) != 4 or len(builds) != 4 or len(set(versions)) != 1 or len(set(builds)) != 1:
    sys.exit("Expected matching app/widget Debug/Release versions; inspect project.pbxproj first.")
def version_tuple(value):
    parts = tuple(map(int, value.split(".")))
    return parts + (0,) * (3 - len(parts))
if version_tuple(version) <= version_tuple(versions[0]) or int(build) <= int(builds[0]):
    sys.exit(f"Version and build must increase beyond {versions[0]} / {builds[0]}.")
text = re.sub(r"MARKETING_VERSION = [\d.]+;", f"MARKETING_VERSION = {version};", text)
text = re.sub(r"CURRENT_PROJECT_VERSION = \d+;", f"CURRENT_PROJECT_VERSION = {build};", text)
project.write_text(text)
print(f"App + widget: {versions[0]} ({builds[0]}) -> {version} ({build})")
