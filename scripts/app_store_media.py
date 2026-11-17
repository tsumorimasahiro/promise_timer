#!/usr/bin/env python3
"""Upload version-scoped App Store screenshots and the Japanese app preview.

Uses Apple's App Asset Library API (OpenAPI 4.6), not the deprecated
appScreenshotSets/appPreviewSets endpoints. ``files`` is entirely local;
``plan`` only reads ASC; ``upload --execute`` changes the specified version.
Old placements are kept until every replacement asset and placement is ready.
Library assets and other device groups are never deleted.

Official contract:
https://developer.apple.com/documentation/appstoreconnectapi/discovering-asset-specifications
https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-image-assets
https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-video-assets
https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces
"""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSETS = ROOT / "Design/AppStore/2026-11-11"
LOCALES = ("ja", "en-US", "ko", "zh-Hans", "zh-Hant")
SCREENSHOTS = ("01-hero.png", "02-timer.png", "03-calendar.png", "04-share.png", "05-profile.png")
CATEGORY = "APP_SCREENSHOTS_AND_PREVIEWS"
READY = {"COMPLETE", "PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW", "ACCEPTED", "APPROVED"}
PLACEMENT_READY = {"PARENT_PREPARE_FOR_SUBMISSION", "PARENT_READY_FOR_REVIEW", "PARENT_WAITING_FOR_REVIEW", "PARENT_IN_REVIEW", "PARENT_APPROVED"}


class MediaError(RuntimeError):
    pass


def unique(items, description):
    if len(items) != 1:
        raise MediaError(f"Expected one {description}; found {len(items)}.")
    return items[0]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_metadata(path):
    # PNG header and transparency chunks, without an optional imaging dependency.
    with path.open("rb") as stream:
        if stream.read(8) != b"\x89PNG\r\n\x1a\n":
            raise MediaError(f"Not a PNG: {path}")
        dimensions = None
        alpha = False
        while True:
            header = stream.read(8)
            if len(header) != 8:
                raise MediaError(f"Truncated PNG: {path}")
            size, kind = struct.unpack(">I4s", header)
            if kind == b"IHDR":
                raw = stream.read(size)
                if len(raw) != 13:
                    raise MediaError(f"Invalid PNG header: {path}")
                width, height, _, color, _, _, _ = struct.unpack(">IIBBBBB", raw)
                dimensions = (width, height)
                alpha = color in (4, 6)
            else:
                stream.seek(size, 1)
            alpha = alpha or kind == b"tRNS"
            if len(stream.read(4)) != 4:
                raise MediaError(f"Truncated PNG: {path}")
            if kind == b"IEND":
                break
        if not dimensions:
            raise MediaError(f"Missing PNG dimensions: {path}")
        return {"width": dimensions[0], "height": dimensions[1], "alpha": alpha}


def load_files(args):
    assets = []
    for locale in args.locales.split(","):
        if locale not in LOCALES:
            raise MediaError(f"Unsupported locale: {locale}")
        for filename in SCREENSHOTS:
            path = args.assets / locale / filename
            assets.append(make_file(path, locale, "APP_SCREENSHOT", png_metadata(path)))
    if not args.skip_preview and "ja" in args.locales.split(","):
        path = args.preview or args.assets / "video/appstore-ja-20s-upload.mp4"
        manifest_name = "upload-manifest.json" if path.name == "appstore-ja-20s-upload.mp4" else "render-manifest.json"
        manifest = json.loads((args.video_manifest or path.parent / manifest_name).read_text())
        match = unique([v for v in manifest.get("outputs", []) if v.get("file") == path.name], "video manifest output")
        file_hash = sha256(path)
        if match.get("sha256") != file_hash:
            raise MediaError("Preview hash differs from its inspected video manifest. Regenerate metadata before uploading.")
        metadata = match.get("metadata", {})
        for key in ("width", "height", "fps", "duration", "audioTracks"):
            if not isinstance(metadata.get(key), (int, float)):
                raise MediaError(f"Video manifest is missing numeric {key}.")
        parts = re.fullmatch(r"(\d{2}):(\d{2}):(\d{2}):(\d{2})", args.poster_timecode)
        if not parts:
            raise MediaError("Poster timecode must be HH:MM:SS:FF.")
        h, m, s, frame = map(int, parts.groups())
        if m >= 60 or s >= 60 or frame >= round(metadata["fps"]) or h * 3600 + m * 60 + s + frame / metadata["fps"] >= metadata["duration"]:
            raise MediaError("Poster timecode falls outside the preview.")
        asset = make_file(path, "ja", "APP_PREVIEW", metadata)
        asset["poster_timecode"] = args.poster_timecode
        # A different poster must not mutate a reused video in another version.
        asset["reference_name"] += ":" + args.poster_timecode.replace(":", "")
        assets.append(asset)
    if len({a["key"] for a in assets}) != len(assets):
        raise MediaError("Duplicate locale in --locales.")
    return assets


def make_file(path, locale, placement_type, metadata):
    kind = "appAssetLibraryImages" if placement_type == "APP_SCREENSHOT" else "appAssetLibraryVideos"
    digest = sha256(path)
    return {"key": f"{locale}/{placement_type}/{path.name}", "path": str(path.resolve()),
            "locale": locale, "placement_type": placement_type, "type": kind,
            "size": path.stat().st_size, "sha256": digest, "metadata": metadata,
            "reference_name": f"pochi:{locale}:{placement_type}:{digest}"}


def duration_seconds(value):
    match = re.fullmatch(r"PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?", value or "")
    if not match:
        raise MediaError(f"Unsupported API duration: {value!r}")
    return sum(float(v or 0) * scale for v, scale in zip(match.groups(), (3600, 60, 1)))


def matching_spec(asset, spec):
    meta = asset["metadata"]
    dims = spec.get("dimensions", {})
    for axis in ("Width", "Height"):
        value = meta[axis.lower()]
        if not dims.get("min" + axis, 0) <= value <= dims.get("max" + axis, 0):
            return False
    suffix = Path(asset["path"]).suffix.lower().lstrip(".")
    if suffix not in [s.lower().lstrip(".") for s in spec.get("fileExtensions", [])]:
        return False
    if asset["size"] > spec.get("maxFileSize", 0):
        return False
    if asset["placement_type"] == "APP_SCREENSHOT":
        return not meta["alpha"] or bool(spec.get("alphaAllowed"))
    if spec.get("audioRequired") and not meta["audioTracks"]:
        return False
    duration = spec.get("duration", {})
    if not duration_seconds(duration.get("min")) <= meta["duration"] <= duration_seconds(duration.get("max")):
        return False
    return any(r["minFps"] - .001 <= meta["fps"] <= r["maxFps"] + .001 for r in spec.get("frameRates", []))


def discover(client, args, assets):
    from app_store_connect import find_version
    version = find_version(client, args.app_id, args.version, "IOS")
    if not version:
        raise MediaError(f"iOS version {args.version} does not exist; prepare the version first.")
    localizations = client.paginate(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    locale_ids = {a["locale"]: unique([loc for loc in localizations if loc["attributes"].get("locale") == a["locale"]], f"{a['locale']} localization")["id"] for a in assets}
    library = client.request("GET", f"/v1/apps/{args.app_id}/assetLibrary")["data"]
    catalog = unique(client.paginate("/v1/appAssetLibraryRefData", {"filter[features]": "APP_STORE_VERSIONS"}), "asset reference catalog")["attributes"]
    groups = [g for g in catalog["placementProfileGroups"] if g.get("platform") == "IPHONE_APP_STORE" and g.get("displayClassId") == args.display_class]
    group = unique(groups, f"iPhone placement group for {args.display_class}")["placementProfileGroupId"]
    feature = unique([f for f in catalog["features"] if f["featureId"] == "APP_STORE_VERSIONS"], "App Store version feature")
    limits = {}
    for asset in assets:
        placement_type = asset["placement_type"]
        policy = unique([p for p in feature["placementPolicies"] if p["placementType"] == placement_type], f"{placement_type} policy")
        limit = unique([g for g in policy["groupLimits"] if group in g["groupIds"]], f"{placement_type} group limit")
        limits[placement_type] = limit["maxCount"]
        accepted = unique([p for p in catalog["placementTypes"] if p["placementTypeId"] == placement_type], f"{placement_type} catalog entry")
        if CATEGORY not in accepted["acceptsAssetCategories"]:
            raise MediaError(f"{placement_type} no longer accepts category {CATEGORY}.")
        mapped = unique([m for m in accepted["specMappings"] if m["placementGroupId"] == group], f"{placement_type} specification map")
        specs = catalog["imageSpecs" if placement_type == "APP_SCREENSHOT" else "videoSpecs"]
        matches = [s["specId"] for s in specs if s["specId"] in mapped["specs"] and matching_spec(asset, s)]
        if not matches:
            raise MediaError(f"{asset['key']} does not match Apple's current {group} specifications (dimensions, alpha/audio, duration, fps, extension or size). No media was changed.")
        asset["allowed_spec_ids"] = matches
    return {"app_id": args.app_id, "version": args.version, "version_id": version["id"],
            "library_id": library["id"], "placement_group": group, "locale_ids": locale_ids,
            "limits": limits, "version_state": version_state(version)}


def linkage(kind, resource_id):
    return {"data": {"type": kind, "id": resource_id}}


def resource_link(resource, relation):
    return (resource.get("relationships", {}).get(relation, {}).get("data") or {}).get("id")


def version_state(resource):
    attrs = resource.get("attributes", {})
    return attrs.get("appVersionState") or attrs.get("appStoreState")


def placements(client, scope, locale, placement_type=None):
    params = {"filter[placementGroup]": scope["placement_group"],
              "sort": "placementGroupPosition", "include": "image,video"}
    if placement_type:
        params["filter[placementType]"] = placement_type
    result = client.paginate(f"/v1/appStoreVersionLocalizations/{scope['locale_ids'][locale]}/placements", params)
    for item in result:
        if item["attributes"].get("placementGroup") != scope["placement_group"]:
            raise MediaError("Server returned a placement outside the requested device group.")
        if placement_type and item["attributes"].get("placementType") != placement_type:
            raise MediaError("Server returned a placement outside the requested placement type.")
    return result


def find_asset(client, scope, asset):
    plural = "images" if asset["type"] == "appAssetLibraryImages" else "videos"
    found = client.paginate(f"/v1/appAssetLibraries/{scope['library_id']}/{plural}", {
        "filter[referenceName]": asset["reference_name"], "filter[category]": CATEGORY})
    found = [r for r in found if r["attributes"].get("referenceName") == asset["reference_name"]]
    if not found:
        return None
    result = unique(found, f"asset with reference {asset['reference_name']}")
    if result["attributes"].get("fileSize") != asset["size"]:
        raise MediaError("Existing asset reference has an unexpected file size.")
    return result


class State:
    def __init__(self, path, scope, assets):
        self.path = path
        identity = {k: scope[k] for k in ("app_id", "version", "version_id", "library_id", "placement_group", "locale_ids")}
        identity["files"] = [{"key": a["key"], "sha256": a["sha256"], "reference_name": a["reference_name"]} for a in assets]
        self.data = json.loads(path.read_text()) if path.exists() else {"schema": 1, "scope": identity, "assets": {}, "baseline": {}, "placements": {}, "complete": False}
        if self.data.get("schema") != 1 or self.data.get("scope") != identity:
            raise MediaError("Resume state belongs to different media or scope. Use a different --state path.")

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(self.path.suffix + ".tmp")
        with tmp.open("w") as stream:
            json.dump(self.data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        tmp.replace(self.path)


@contextlib.contextmanager
def state_lock(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.with_suffix(path.suffix + ".lock").open("a") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise MediaError("Another media upload is using this state file.") from None
        yield


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def validate_operations(operations, size):
    cursor = 0
    if not operations:
        raise MediaError("The reservation has no upload operations; rerun to fetch fresh upload URLs.")
    for op in sorted(operations, key=lambda x: x.get("offset", -1)):
        if op.get("method") != "PUT" or urllib.parse.urlsplit(op.get("url", "")).scheme != "https":
            raise MediaError("Unexpected upload method or non-HTTPS upload URL.")
        if op.get("offset") != cursor or not isinstance(op.get("length"), int) or op["length"] <= 0:
            raise MediaError("Upload parts overlap, leave a gap, or have an invalid length.")
        cursor += op["length"]
    if cursor != size:
        raise MediaError("Upload operations do not cover the complete file.")


def upload_parts(asset, operations):
    validate_operations(operations, asset["size"])
    if sha256(Path(asset["path"])) != asset["sha256"]:
        raise MediaError("A local media file changed after planning.")
    opener = urllib.request.build_opener(NoRedirect())
    with open(asset["path"], "rb") as stream:
        for index, op in enumerate(operations):
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            # Signed upload operations supply their own headers; never add ASC JWTs.
            stream.seek(op["offset"])
            content = stream.read(op["length"])
            if len(content) != op["length"]:
                raise MediaError("Media file changed during upload.")
            for attempt in range(3):
                request = urllib.request.Request(op["url"], data=content, headers=headers, method="PUT")
                try:
                    with opener.open(request, timeout=90) as response:
                        if not 200 <= response.status < 300:
                            raise MediaError(f"Upload part {index + 1} returned HTTP {response.status}.")
                    break
                except urllib.error.HTTPError as exc:
                    status = exc.code
                    exc.close()
                    if status not in (408, 429, 500, 502, 503, 504) or attempt == 2:
                        raise MediaError(f"Upload part {index + 1} returned HTTP {status}; rerun to resume.") from None
                except (urllib.error.URLError, TimeoutError, OSError):
                    if attempt == 2:
                        raise MediaError(f"Upload part {index + 1} failed; rerun to resume with fresh URLs.") from None
                time.sleep(2 ** attempt)


def poll(client, path, timeout, interval, ready, description, video=False, expected_spec_ids=None, read_params=None):
    deadline = time.monotonic() + timeout
    while True:
        response = client.request("GET", path, params=read_params) if read_params else client.request("GET", path)
        resource = response["data"]
        attrs = resource["attributes"]
        state = attrs.get("state")
        frame = (attrs.get("previewFrameImage") or {}).get("state") or {}
        if state in {"FAILED", "REJECTED", "ARCHIVED"} or (video and frame.get("state") == "FAILED"):
            # No raw response is logged: it can contain signed media URLs.
            raise MediaError(f"{description} processing failed ({state}, poster={frame.get('state')}). Resource {resource['id']}; inspect stateDetails in ASC.")
        spec_id = attrs.get("specId")
        # ASC can expose PREPARE_FOR_SUBMISSION before its processed specId is
        # visible. Wait for that field within the same bounded poll, instead of
        # rejecting a valid asset or reserving another upload on the next run.
        if state in ready and expected_spec_ids is not None and spec_id and spec_id not in expected_spec_ids:
            raise MediaError(f"Processed asset {resource['id']} has an unexpected specification; existing placements are unchanged.")
        spec_ready = expected_spec_ids is None or spec_id in expected_spec_ids
        if state in ready and spec_ready and (not video or (frame.get("state") == "COMPLETE" and (attrs.get("previewFrameImage") or {}).get("image"))):
            return resource
        if time.monotonic() >= deadline:
            raise MediaError(f"Timed out waiting for {description} ({state}); rerun to resume. Existing media remains until replacements are ready.")
        time.sleep(min(interval, max(0, deadline - time.monotonic())))


def stage_asset(client, scope, asset, state):
    """Reserve and transfer one asset, allowing Apple processing to continue."""
    resource = find_asset(client, scope, asset)
    remembered = state.data["assets"].get(asset["key"], {})
    if remembered.get("id") and (not resource or resource["id"] != remembered["id"]):
        raise MediaError(f"Previously reserved asset for {asset['key']} disappeared or changed. Refusing a duplicate reservation.")
    if not resource:
        attrs = {"fileName": Path(asset["path"]).name, "fileSize": asset["size"], "category": CATEGORY, "referenceName": asset["reference_name"]}
        if asset["placement_type"] == "APP_PREVIEW":
            attrs["previewFrameTimeCode"] = asset["poster_timecode"]
        resource = client.request("POST", f"/v1/{asset['type']}", {"data": {"type": asset["type"], "attributes": attrs,
            "relationships": {"assetLibrary": linkage("appAssetLibraries", scope["library_id"])}}})["data"]
    asset_id = resource["id"]
    state.data["assets"][asset["key"]] = {"id": asset_id, "type": asset["type"], "sha256": asset["sha256"], "locale": asset["locale"], "placement_type": asset["placement_type"], "state": resource["attributes"].get("state")}
    state.save()
    path = f"/v1/{asset['type']}/{asset_id}"
    if resource["attributes"].get("state") == "AWAITING_UPLOAD":
        resource = client.request("GET", path)["data"]
        # A collection read can lag behind this individual resource read.
        # Never upload again when the current resource is already committed.
        if resource["attributes"].get("state") == "AWAITING_UPLOAD":
            upload_parts(asset, resource["attributes"].get("uploadOperations", []))
            # The current Asset Library API explicitly has no sourceFileChecksum.
            resource = client.request("PATCH", path, {"data": {"type": asset["type"], "id": asset_id, "attributes": {"uploaded": True}}})["data"]
    asset_state = resource["attributes"].get("state")
    state.data["assets"][asset["key"]]["state"] = asset_state
    state.save()
    if asset_state in {"FAILED", "REJECTED", "ARCHIVED"}:
        raise MediaError(f"{asset['key']} processing failed ({asset_state}). Resource {asset_id}; existing placements are unchanged.")
    return resource


def wait_for_asset(client, asset, state, args):
    """Verify the committed asset before any placement can be changed."""
    asset_id = state.data["assets"][asset["key"]]["id"]
    path = f"/v1/{asset['type']}/{asset_id}"
    resource = poll(client, path, args.timeout, args.poll_interval, READY, asset["key"],
                    video=asset["placement_type"] == "APP_PREVIEW", expected_spec_ids=asset["allowed_spec_ids"])
    if resource["attributes"].get("specId") not in asset["allowed_spec_ids"]:
        raise MediaError(f"Processed asset {asset_id} has an unexpected specification; existing placements are unchanged.")
    state.data["assets"][asset["key"]]["state"] = resource["attributes"]["state"]
    state.save()
    return resource


def ensure_asset(client, scope, asset, state, args):
    """Prepare one asset; the upload workflow stages batches before waiting."""
    stage_asset(client, scope, asset, state)
    return wait_for_asset(client, asset, state, args)


def compact_placement(p):
    return {"id": p["id"], "placement_type": p["attributes"].get("placementType"), "image": resource_link(p, "image"), "video": resource_link(p, "video")}


def preflight(client, scope, assets, state=None):
    existing_assets = {a["key"]: find_asset(client, scope, a) for a in assets}
    groups = {locale: placements(client, scope, locale) for locale in scope["locale_ids"]}
    for locale, current in groups.items():
        for placement_type in {a["placement_type"] for a in assets if a["locale"] == locale}:
            relation = "image" if placement_type == "APP_SCREENSHOT" else "video"
            current_type = [p for p in current if p["attributes"].get("placementType") == placement_type]
            missing = sum(1 for a in assets if a["locale"] == locale and a["placement_type"] == placement_type and not any(existing_assets[a["key"]] and resource_link(p, relation) == existing_assets[a["key"]]["id"] for p in current_type))
            if len(current_type) + missing > scope["limits"][placement_type]:
                raise MediaError(f"{locale} {placement_type}: {len(current_type)} existing + {missing} replacements exceeds Apple's {scope['limits'][placement_type]} limit. Existing placements were preserved; free capacity explicitly before rerunning.")
        if state:
            baseline = state.data["baseline"].setdefault(locale, [compact_placement(p) for p in current])
            baseline_ids = {p["id"] for p in baseline}
            owned_asset_ids = {r["id"] for r in existing_assets.values() if r}
            for p in current:
                if p["id"] not in baseline_ids and resource_link(p, "image") not in owned_asset_ids and resource_link(p, "video") not in owned_asset_ids:
                    raise MediaError(f"{locale} placements changed concurrently. Refusing to remove any media.")
    if state:
        state.save()
    return groups, existing_assets


def assert_editable(client, scope):
    version = client.request("GET", f"/v1/appStoreVersions/{scope['version_id']}")["data"]
    state = version_state(version)
    if state not in {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}:
        raise MediaError(f"Version state {state} is not editable; no placement changes permitted.")


def wait_for_placement(client, scope, asset, state, args, placement_id):
    resource = poll(client, f"/v1/appAssetLibraryPlacements/{placement_id}", args.timeout,
                    args.poll_interval, PLACEMENT_READY | {"ACTIVE"}, asset["key"] + " placement",
                    read_params={"include": "image,video,appStoreVersionLocalization"})
    if resource["attributes"].get("state") != "ACTIVE":
        return resource
    # The live API returned ACTIVE for inherited and newly created placements
    # on 2026-11-11, although OpenAPI 4.6 still lists only PARENT_* states. Treat
    # this observed value as compatible only after verifying the complete target
    # and the processed asset; do not generally accept undocumented states.
    attrs = resource["attributes"]
    relation = "image" if asset["placement_type"] == "APP_SCREENSHOT" else "video"
    opposite = "video" if relation == "image" else "image"
    expected_asset = state.data["assets"][asset["key"]]["id"]
    expected_locale = scope["locale_ids"][asset["locale"]]
    if (resource["id"] != placement_id or attrs.get("stateDetails")
            or attrs.get("placementType") != asset["placement_type"]
            or attrs.get("placementGroup") != scope["placement_group"]
            or attrs.get("mediaType") != relation.upper()
            or resource_link(resource, relation) != expected_asset
            or resource_link(resource, opposite) is not None):
        raise MediaError(f"ACTIVE placement {placement_id} does not match the expected processed asset and target.")
    parent_id = resource_link(resource, "appStoreVersionLocalization")
    if parent_id is not None and parent_id != expected_locale:
        raise MediaError(f"ACTIVE placement {placement_id} belongs to a different localization.")
    if parent_id is None and not any(p["id"] == placement_id for p in placements(client, scope, asset["locale"])):
        raise MediaError(f"ACTIVE placement {placement_id} is absent from the expected localization.")
    wait_for_asset(client, asset, state, args)
    assert_editable(client, scope)
    return resource


def order_group(client, scope, locale, ids):
    current = placements(client, scope, locale)
    by_id = {p["id"]: p for p in current}
    if len(ids) != len(set(ids)) or set(ids) != set(by_id):
        raise MediaError(f"{locale} placements changed before ordering; no ordering request was sent.")
    by_type = {}
    for placement_id in ids:
        placement_type = by_id[placement_id]["attributes"].get("placementType")
        if not placement_type:
            raise MediaError("Cannot order a placement without its placementType.")
        by_type.setdefault(placement_type, []).append(placement_id)
    # The API requires every ID in an ordering request to share placementType,
    # in addition to the same group and localization. Cross-type ordering is not
    # defined: previews and screenshots each have their own display sequence.
    for placement_type, ordered_ids in by_type.items():
        existing = [p["id"] for p in current if p["attributes"].get("placementType") == placement_type]
        if existing == ordered_ids:
            continue
        client.request("POST", "/v1/appAssetLibraryPlacementOrderingRequests", {"data": {
            "type": "appAssetLibraryPlacementOrderingRequests", "attributes": {"placementGroup": scope["placement_group"]},
            "relationships": {"appStoreVersionLocalization": linkage("appStoreVersionLocalizations", scope["locale_ids"][locale]),
                              "orderedPlacements": {"data": [{"type": "appAssetLibraryPlacements", "id": i} for i in ordered_ids]}}}})
        # A write is sent once per type. Only reads are retried for visibility.
        for attempt in range(6):
            actual = [p["id"] for p in placements(client, scope, locale, placement_type)]
            if actual == ordered_ids:
                break
            if attempt < 5:
                time.sleep(1)
        else:
            raise MediaError(f"{locale} {placement_type} placement ordering has not been confirmed. Rerun to resume.")


def upload(client, scope, assets, state, args):
    assert_editable(client, scope)
    preflight(client, scope, assets, state)
    # Upload sequentially but overlap Apple's asynchronous processing. Every
    # reservation is journaled before transfer, so interruption can resume it.
    for asset in assets:
        print(f"Uploading {asset['key']}", file=sys.stderr, flush=True)
        stage_asset(client, scope, asset, state)
    # This complete-batch readiness gate precedes every placement mutation.
    for asset in assets:
        print(f"Waiting for {asset['key']}", file=sys.stderr, flush=True)
        wait_for_asset(client, asset, state, args)
    assert_editable(client, scope)
    preflight(client, scope, assets, state)
    # Stage and validate every placement before removing any old placement.
    for locale in scope["locale_ids"]:
        current = placements(client, scope, locale)
        for asset in [a for a in assets if a["locale"] == locale]:
            asset_id = state.data["assets"][asset["key"]]["id"]
            relation = "image" if asset["placement_type"] == "APP_SCREENSHOT" else "video"
            found = [p for p in current if p["attributes"].get("placementType") == asset["placement_type"] and resource_link(p, relation) == asset_id]
            if len(found) > 1:
                raise MediaError(f"Duplicate placements for {asset['key']}; refusing automatic removal.")
            if found:
                placement = found[0]
            else:
                placement = client.request("POST", "/v1/appAssetLibraryPlacements", {"data": {
                    "type": "appAssetLibraryPlacements", "attributes": {"placementType": asset["placement_type"], "placementGroup": scope["placement_group"]},
                    "relationships": {relation: linkage(asset["type"], asset_id), "appStoreVersionLocalization": linkage("appStoreVersionLocalizations", scope["locale_ids"][locale])}}})["data"]
                current.append(placement)
            state.data["placements"][asset["key"]] = {"id": placement["id"], "locale_id": scope["locale_ids"][locale], "placement_group": scope["placement_group"], "asset_id": asset_id}
            state.save()
            wait_for_placement(client, scope, asset, state, args, placement["id"])
    # Recheck concurrent edits across all locales before removing old placements.
    preflight(client, scope, assets, state)
    assert_editable(client, scope)
    for locale in scope["locale_ids"]:
        current = placements(client, scope, locale)
        local_assets = [a for a in assets if a["locale"] == locale]
        targeted_types = {a["placement_type"] for a in local_assets}
        desired = [state.data["placements"][a["key"]]["id"] for a in sorted(local_assets, key=lambda a: (a["placement_type"] != "APP_PREVIEW", a["key"]))]
        old = [p for p in current if p["attributes"].get("placementType") in targeted_types and p["id"] not in desired]
        baseline_ids = {p["id"] for p in state.data["baseline"][locale]}
        if any(p["id"] not in baseline_ids for p in old):
            raise MediaError("An unrecognized placement appeared; refusing to remove it.")
        preserved = [p["id"] for p in current if p["attributes"].get("placementType") not in targeted_types]
        # Other types (including non-Japanese previews) remain in their own order.
        final_order = preserved + desired
        # Verify replacement order before removing originals, so a reorder error
        # leaves all old media still placed and visible for recovery.
        interim = final_order + [p["id"] for p in old]
        if [p["id"] for p in current] != interim:
            order_group(client, scope, locale, interim)
        for p in old:
            client.request("DELETE", f"/v1/appAssetLibraryPlacements/{p['id']}")
            state.data.setdefault("removed_placements", []).append(p["id"])
            state.save()
        if [p["id"] for p in placements(client, scope, locale)] != final_order:
            order_group(client, scope, locale, final_order)
    state.data["complete"] = True
    state.save()
    return {"complete": True, **scope, "assets": list(state.data["assets"].values()),
            "placements": list(state.data["placements"].values()), "extra_items": [],
            "review_note": "Screenshot and preview placements are reviewed with their App Store version; submit the parent version.", "state_file": str(state.path)}


def parser():
    result = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    result.add_argument("command", choices=("files", "plan", "upload"))
    result.add_argument("--app-id", help="Exact ASC app ID; required for plan/upload")
    result.add_argument("--version", help="Exact iOS marketing version; required for plan/upload")
    result.add_argument("--config", type=Path, help="Same private API-key configuration as app_store_connect.py")
    result.add_argument("--assets", type=Path, default=DEFAULT_ASSETS)
    result.add_argument("--locales", default=",".join(LOCALES))
    result.add_argument("--preview", type=Path)
    result.add_argument("--video-manifest", type=Path, help="Inspected render-manifest.json containing the preview's SHA-256 and metadata")
    result.add_argument("--poster-timecode", default="00:00:03:00")
    result.add_argument("--skip-preview", action="store_true", help="Leave every existing app preview unchanged")
    result.add_argument("--display-class", default="IPHONE_DYNAMIC_ISLAND_LARGE_DISPLAY", help="Resolve this display class through current Apple reference data")
    result.add_argument("--state", type=Path, help="Resume journal; default .build/asc-media/APP-VERSION.json")
    result.add_argument("--receipt", type=Path, help="Write a safe JSON plan/result without tokens or signed URLs")
    result.add_argument("--timeout", type=int, default=600, help="Maximum processing wait per asset/placement, seconds")
    result.add_argument("--poll-interval", type=int, default=5)
    result.add_argument("--execute", action="store_true", help="Required to upload and replace only the specified version's targeted media")
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    if args.timeout < 1 or not 1 <= args.poll_interval <= 30:
        raise MediaError("Use a positive timeout and a poll interval between 1 and 30 seconds.")
    if args.command == "upload" and not args.execute:
        raise MediaError("Uploading requires --execute. Use plan for a read-only preview.")
    assets = load_files(args)
    if args.command == "files":
        result = {"local_only": True, "assets": assets}
    else:
        if not args.app_id or not args.version:
            raise MediaError("--app-id and --version are required.")
        from app_store_connect import ASCClient, AuthConfig
        client = ASCClient(AuthConfig.load(args.config))
        scope = discover(client, args, assets)
        if args.command == "plan":
            groups, known = preflight(client, scope, assets)
            result = {"read_only": True, **scope, "assets": assets,
                      "reusable_asset_ids": {k: r["id"] if r else None for k, r in known.items()},
                      "current_placements": {loc: [compact_placement(p) for p in group] for loc, group in groups.items()}}
        else:
            if not re.fullmatch(r"[A-Za-z0-9._-]+", args.app_id + args.version):
                raise MediaError("Invalid app ID/version for a state filename.")
            state_path = args.state or ROOT / ".build/asc-media" / f"{args.app_id}-{args.version}.json"
            with state_lock(state_path):
                state = State(state_path, scope, assets)
                result = upload(client, scope, assets, state, args)
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(output)
    print(output, end="")


if __name__ == "__main__":
    from app_store_connect import WorkflowError
    try:
        main()
    except (MediaError, WorkflowError, OSError, ValueError) as exc:
        print(f"Media upload stopped: {exc}", file=sys.stderr)
        sys.exit(1)
