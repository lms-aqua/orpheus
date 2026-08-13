#!/usr/bin/env python3
"""Generate the AltStore source JSON from this repository's GitHub Releases.

    gh api repos/:owner/:repo/releases --paginate \
      | py -3.11 Scripts/generate-altstore-source.py --output site/altstore.json

Version history is *derived* from releases rather than maintained by hand. That
matters: a hand-edited source file drifts from what is actually downloadable, and
AltStore will happily offer an update whose asset no longer exists.

AltStore shows the first entry in `versions` whose OS range matches the device as
the latest release, regardless of version number or date, so the array must be
in reverse chronological order. Releases come back newest-first from the API and
that order is preserved.

Per-release build metadata is read out of a machine-readable block in the release
body, which the release workflow writes:

    <!-- orpheus-metadata
    build=42
    minOS=26.0
    sha256=<hex>
    -->
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

METADATA_BLOCK = re.compile(
    r"<!--\s*orpheus-metadata(?P<body>.*?)-->",
    re.DOTALL | re.IGNORECASE,
)

DEFAULT_MIN_OS = "26.0"


def parse_metadata(body: str | None) -> dict[str, str]:
    """Pull key=value pairs out of the release body's metadata block."""
    if not body:
        return {}
    match = METADATA_BLOCK.search(body)
    if not match:
        return {}
    found: dict[str, str] = {}
    for line in match.group("body").splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        key, _, value = line.partition("=")
        found[key.strip()] = value.strip()
    return found


def human_notes(body: str | None) -> str:
    """Release notes with the machine-readable block stripped out."""
    if not body:
        return ""
    return METADATA_BLOCK.sub("", body).strip()


def version_from_tag(tag: str) -> str:
    """`v1.2.3` -> `1.2.3`. AltStore compares these, so the `v` must go."""
    return tag[1:] if tag.lower().startswith("v") else tag


def build_versions(releases: list[dict], *, include_prereleases: bool) -> list[dict]:
    versions: list[dict] = []

    for release in releases:
        if release.get("draft"):
            continue
        if release.get("prerelease") and not include_prereleases:
            continue

        ipa = next(
            (
                asset
                for asset in release.get("assets", [])
                if asset.get("name", "").endswith(".ipa")
            ),
            None,
        )
        if ipa is None:
            # A release with no .ipa cannot be installed; skip rather than
            # publish an entry that would fail on download.
            print(
                f"note: release {release.get('tag_name')} has no .ipa asset, skipping",
                file=sys.stderr,
            )
            continue

        metadata = parse_metadata(release.get("body"))
        version = version_from_tag(release.get("tag_name", ""))

        entry = {
            "version": version,
            # AltStore expects a build version; fall back to the marketing
            # version when the release did not record one.
            "buildVersion": metadata.get("build", version),
            "date": release.get("published_at") or release.get("created_at"),
            "downloadURL": ipa["browser_download_url"],
            # Taken from the asset itself, so it can never disagree with the
            # file AltStore actually downloads.
            "size": ipa["size"],
            "minOSVersion": metadata.get("minOS", DEFAULT_MIN_OS),
        }

        notes = human_notes(release.get("body"))
        if notes:
            entry["localizedDescription"] = notes

        versions.append(entry)

    return versions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--template",
        type=pathlib.Path,
        default=pathlib.Path("AltStore/source-template.json"),
    )
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument(
        "--icon-url",
        default="",
        help="Absolute URL to the app icon PNG, required by AltStore.",
    )
    parser.add_argument("--include-prereleases", action="store_true")
    parser.add_argument(
        "--releases",
        type=pathlib.Path,
        help="File containing the GitHub releases JSON. Defaults to stdin.",
    )
    args = parser.parse_args()

    raw = (
        args.releases.read_text(encoding="utf-8")
        if args.releases
        else sys.stdin.read()
    )
    releases = json.loads(raw or "[]")
    if isinstance(releases, dict):
        releases = [releases]

    source = json.loads(args.template.read_text(encoding="utf-8"))
    app = source["apps"][0]

    if args.icon_url:
        source["iconURL"] = args.icon_url
        app["iconURL"] = args.icon_url

    app["versions"] = build_versions(
        releases, include_prereleases=args.include_prereleases
    )

    if not app["versions"]:
        # Emitting a source with an empty versions array is worse than failing:
        # AltStore would show an app that cannot be installed.
        print(
            "error: no installable releases found, refusing to write an empty source",
            file=sys.stderr,
        )
        return 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(source, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    latest = app["versions"][0]
    print(f"Wrote {args.output} with {len(app['versions'])} version(s)")
    print(f"  latest: {latest['version']} ({latest['buildVersion']}), {latest['size']} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
