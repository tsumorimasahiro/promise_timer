#!/usr/bin/env python3
"""App Store Connect API release preparation and submission.

No browser cookies, Apple Account passwords, or third-party Python packages are
required. Credentials stay in a private local config or environment variables.
The script never prints a JWT or private key and never retries an ambiguous write.

Auth: ASC_KEY_ID, ASC_KEY_PATH, ASC_ISSUER_ID (team keys), ASC_KEY_TYPE
(team/individual), or --config with key_id/key_path/issuer_id/key_type.
ASC_CONFIG may name that private config. Individual keys use sub=user, not iss.

Typical workflow (binary upload and media are separate steps):
  python3 scripts/app_store_connect.py --config /private/path/asc.json inspect
  python3 scripts/app_store_connect.py --config /private/path/asc.json prepare \
    --listing Design/AppStore/2026-11-11/release-listing.json \
    --review-notes Design/AppStore/2026-11-11/review-notes.txt \
    --output .build/asc-prepared.json
  python3 scripts/app_store_connect.py --config /private/path/asc.json submit \
    --prepared .build/asc-prepared.json --output .build/asc-submitted.json

Apple references (OpenAPI 4.6, checked 2026-11-11):
https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissions
https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissionitems
https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-reviewsubmissions-_id_
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

API_ORIGIN = "https://api.appstoreconnect.apple.com"
DEFAULT_APP_ID = "6760613210"
DEFAULT_BUNDLE_ID = "max.promise-timer"
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
    "METADATA_REJECTED", "INVALID_BINARY", "READY_FOR_REVIEW",
    "WAITING_FOR_EXPORT_COMPLIANCE",
}
SUBMITTED_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING"}
FINISHED_VERSION_STATES = {
    "READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "PENDING_DEVELOPER_RELEASE",
    "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE", "PROCESSING_FOR_DISTRIBUTION",
}
LOCALIZATION_FIELDS = ("description", "whatsNew", "marketingUrl", "supportUrl", "promotionalText")
FINGERPRINT_FIELDS = LOCALIZATION_FIELDS + ("keywords",)


class WorkflowError(RuntimeError):
    """A concrete state/configuration issue; no automatic destructive recovery."""


class APIError(WorkflowError):
    def __init__(self, status: int, errors: list[dict[str, Any]] | None = None):
        self.status = status
        self.errors = errors or []
        self.code = self.errors[0].get("code", "HTTP_ERROR") if self.errors else "HTTP_ERROR"
        messages: list[str] = []

        def describe(error: dict[str, Any], depth: int) -> None:
            if depth > 12 or len(messages) >= 40:
                return
            parts = [error[k] for k in ("code", "title", "detail") if isinstance(error.get(k), str) and error[k]]
            source = error.get("source")
            if isinstance(source, dict) and isinstance(source.get("pointer"), str):
                parts.append("source.pointer=" + source["pointer"])
            if parts:
                messages.append(": ".join(parts))
            meta = error.get("meta")
            if isinstance(meta, dict):
                associated(meta.get("associatedErrors"), depth + 1)

        def associated(value: Any, depth: int) -> None:
            # Apple may key associatedErrors by a resource URL. Traverse that
            # container, but emit only error fields, never keys or arbitrary meta.
            if depth > 12 or len(messages) >= 40:
                return
            if isinstance(value, list):
                for child in value:
                    associated(child, depth + 1)
            elif isinstance(value, dict):
                if any(k in value for k in ("code", "title", "detail", "source", "meta")):
                    describe(value, depth)
                else:
                    for child in value.values():
                        associated(child, depth + 1)

        for error in self.errors:
            if isinstance(error, dict):
                describe(error, 0)
        text = "; ".join(messages)
        text = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[JWT redacted]", text)
        text = re.sub(r"-----BEGIN .*?PRIVATE KEY-----.*?-----END .*?PRIVATE KEY-----", "[key redacted]", text, flags=re.S)
        super().__init__(f"App Store Connect HTTP {status}: {text[:2500] or self.code}")


@dataclass(frozen=True)
class AuthConfig:
    key_id: str
    key_path: Path
    issuer_id: str | None = None
    key_type: str = "team"

    @classmethod
    def load(cls, config_path: str | Path | None = None) -> "AuthConfig":
        config_path = config_path or os.environ.get("ASC_CONFIG")
        values: dict[str, Any] = {}
        base = Path.cwd()
        if config_path:
            path = Path(config_path).expanduser().resolve()
            try:
                values = json.loads(path.read_text())
            except (OSError, ValueError):
                raise WorkflowError("Cannot read the private ASC config as JSON.") from None
            if not isinstance(values, dict):
                raise WorkflowError("ASC config must be a JSON object.")
            base = path.parent
        key_id = os.environ.get("ASC_KEY_ID") or values.get("key_id")
        key_path = os.environ.get("ASC_KEY_PATH") or values.get("key_path")
        issuer = os.environ.get("ASC_ISSUER_ID") or values.get("issuer_id")
        key_type = os.environ.get("ASC_KEY_TYPE") or values.get("key_type") or ("team" if issuer else "individual")
        if not key_id or not key_path:
            raise WorkflowError("Set ASC_KEY_ID and ASC_KEY_PATH, or provide --config with key_id/key_path.")
        if not isinstance(key_id, str) or not isinstance(key_path, str) or (issuer is not None and not isinstance(issuer, str)):
            raise WorkflowError("ASC key_id, key_path, and issuer_id must be text.")
        if key_type not in ("team", "individual"):
            raise WorkflowError("key_type must be team or individual.")
        if key_type == "team" and not issuer:
            raise WorkflowError("A team API key also requires ASC_ISSUER_ID / issuer_id.")
        if key_type == "individual" and issuer:
            raise WorkflowError("Individual API keys use sub=user and must not configure an issuer_id.")
        path = Path(key_path).expanduser()
        if not path.is_absolute():
            path = base / path
        if not path.is_file():
            raise WorkflowError("The configured ASC private-key file does not exist.")
        return cls(str(key_id), path.resolve(), str(issuer) if issuer else None, key_type)


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _der_ecdsa_to_raw(signature: bytes) -> bytes:
    """Convert OpenSSL's ASN.1 DER ECDSA signature to JOSE's 32-byte r || s."""
    pos = 0

    def element(tag: int) -> bytes:
        nonlocal pos
        if pos + 2 > len(signature) or signature[pos] != tag:
            raise WorkflowError("The signing key did not produce an ES256 signature.")
        pos += 1
        length = signature[pos]
        pos += 1
        if length & 0x80:
            count = length & 0x7f
            if count not in (1, 2) or pos + count > len(signature):
                raise WorkflowError("Invalid DER signature length.")
            length = int.from_bytes(signature[pos:pos + count], "big")
            pos += count
        end = pos + length
        if end > len(signature):
            raise WorkflowError("Truncated DER signature.")
        value = signature[pos:end]
        pos = end
        return value

    sequence = element(0x30)
    if pos != len(signature):
        raise WorkflowError("Trailing signature data.")
    signature = sequence
    pos = 0
    numbers = []
    for _ in range(2):
        value = element(0x02)
        if not value or value[0] & 0x80:
            raise WorkflowError("Invalid ECDSA integer.")
        value = value.lstrip(b"\0")
        if len(value) > 32:
            raise WorkflowError("The signing key must use the P-256 curve.")
        numbers.append(value.rjust(32, b"\0"))
    if pos != len(signature):
        raise WorkflowError("Unexpected ECDSA signature fields.")
    return b"".join(numbers)


def make_jwt(auth: AuthConfig, now: int | None = None) -> str:
    now = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": auth.key_id, "typ": "JWT"}
    payload: dict[str, Any] = {"iat": now - 5, "exp": now + 600, "aud": "appstoreconnect-v1"}
    payload["iss" if auth.key_type == "team" else "sub"] = auth.issuer_id if auth.key_type == "team" else "user"
    unsigned = ".".join(_b64(json.dumps(v, separators=(",", ":")).encode()) for v in (header, payload)).encode()
    try:
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
    except ImportError:
        # The key contents are never passed in arguments, stdout, or a temporary file.
        try:
            public_key = subprocess.run(
                ["openssl", "pkey", "-in", str(auth.key_path), "-pubout", "-outform", "DER"],
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
            )
            # SubjectPublicKeyInfo: id-ecPublicKey, prime256v1, uncompressed point.
            p256_header = bytes.fromhex("3059301306072a8648ce3d020106082a8648ce3d03010703420004")
            if public_key.returncode or len(public_key.stdout) != 91 or not public_key.stdout.startswith(p256_header):
                raise WorkflowError("The ASC private key must be an unencrypted P-256 key.")
            result = subprocess.run(
                ["openssl", "dgst", "-sha256", "-sign", str(auth.key_path)],
                input=unsigned, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
            )
        except OSError:
            raise WorkflowError("Install OpenSSL or Python cryptography to sign ASC API requests.") from None
        if result.returncode:
            raise WorkflowError("OpenSSL could not sign with the configured API private key.")
        signature = _der_ecdsa_to_raw(result.stdout)
    else:
        try:
            key = serialization.load_pem_private_key(auth.key_path.read_bytes(), password=None)
            if not isinstance(key, ec.EllipticCurvePrivateKey) or key.curve.name != "secp256r1":
                raise WorkflowError("The ASC private key must use P-256.")
            signature = _der_ecdsa_to_raw(key.sign(unsigned, ec.ECDSA(hashes.SHA256())))
        except (ValueError, TypeError, OSError):
            raise WorkflowError("Cannot load the configured ASC API private key.") from None
    return unsigned.decode() + "." + _b64(signature)


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req: Any, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> None:
        # Never forward the bearer token to an upload/storage host or redirect.
        return None


class ASCClient:
    def __init__(self, auth: AuthConfig, timeout: int = 60):
        self.auth = auth
        self.timeout = timeout
        self._token = ""
        self._token_created = 0.0
        self._opener = build_opener(_NoRedirect())

    def request(self, method: str, path: str, data: Any = None, params: dict[str, Any] | None = None) -> dict[str, Any]:
        method = method.upper()
        url = API_ORIGIN + path if path.startswith("/") else path
        parsed = urlsplit(url)
        if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com" or parsed.username or parsed.fragment:
            raise WorkflowError("ASCClient only sends credentials to https://api.appstoreconnect.apple.com.")
        if params:
            encoded = {k: ",".join(map(str, v)) if isinstance(v, (list, tuple)) else str(v) for k, v in params.items() if v is not None}
            url += ("&" if parsed.query else "?") + urlencode(encoded)
        if not self._token or time.time() - self._token_created > 540:
            self._token = make_jwt(self.auth)
            self._token_created = time.time()
        body = None if data is None else json.dumps(data, ensure_ascii=False).encode("utf-8")
        request = Request(url, data=body, method=method, headers={
            "Authorization": "Bearer " + self._token,
            "Accept": "application/json", "Content-Type": "application/json",
            "User-Agent": "Pochi-AppStoreConnect/1.0",
        })
        for attempt in range(3):
            try:
                with self._opener.open(request, timeout=self.timeout) as response:
                    raw = response.read()
                return json.loads(raw) if raw else {}
            except HTTPError as error:
                raw = error.read()
                if method == "GET" and error.code in (429, 500, 502, 503, 504) and attempt < 2:
                    retry = error.headers.get("Retry-After", "")
                    time.sleep(min(int(retry), 20) if retry.isdigit() else (2 ** attempt))
                    continue
                try:
                    errors = json.loads(raw).get("errors", [])
                except (ValueError, AttributeError):
                    errors = []
                raise APIError(error.code, errors) from None
            except (URLError, TimeoutError, OSError):
                if method == "GET" and attempt < 2:
                    time.sleep(2 ** attempt)
                    continue
                suffix = " Inspect server state before retrying this write." if method != "GET" else ""
                attempts = " after 3 attempts" if method == "GET" else ""
                raise WorkflowError("ASC network request failed" + attempts + "." + suffix) from None
        raise WorkflowError("ASC read retries exhausted.")

    def paginate(self, path: str, params: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        result: list[dict[str, Any]] = []
        seen: set[str] = set()
        while path:
            if path in seen or len(seen) >= 1000:
                raise WorkflowError("Unexpected pagination cycle or excessive page count.")
            seen.add(path)
            response = self.request("GET", path, params=params)
            data = response.get("data", [])
            if not isinstance(data, list):
                raise WorkflowError("Expected a list response while paginating.")
            result.extend(data)
            path = response.get("links", {}).get("next")
            params = None
        return result


def relationship(resource: dict[str, Any], name: str) -> Any:
    return resource.get("relationships", {}).get(name, {}).get("data")


def version_state(version: dict[str, Any]) -> str | None:
    a = version.get("attributes", {})
    return a.get("appVersionState") or a.get("appStoreState")


def find_version(client: ASCClient, app_id: str, version: str, platform: str = "IOS") -> dict[str, Any] | None:
    rows = client.paginate(f"/v1/apps/{app_id}/appStoreVersions", {
        "filter[versionString]": version, "filter[platform]": platform, "limit": 200,
    })
    rows = [r for r in rows if r.get("attributes", {}).get("versionString") == version and r.get("attributes", {}).get("platform") == platform]
    if len(rows) > 1:
        raise WorkflowError("More than one App Store version matches; refusing an ambiguous update.")
    return rows[0] if rows else None


def verify_app(client: ASCClient, app_id: str, bundle_id: str) -> dict[str, Any]:
    app = client.request("GET", f"/v1/apps/{app_id}")["data"]
    if app.get("attributes", {}).get("bundleId") != bundle_id:
        raise WorkflowError("The app ID does not match the expected bundle ID.")
    return app


def find_build(client: ASCClient, app_id: str, version: str, build_number: str, platform: str = "IOS", require_valid: bool = True) -> dict[str, Any] | None:
    builds = client.paginate("/v1/builds", {
        "filter[app]": app_id, "filter[version]": build_number,
        "filter[preReleaseVersion.version]": version,
        "filter[preReleaseVersion.platform]": platform, "include": "preReleaseVersion,app", "limit": 200,
    })
    if len(builds) > 1:
        raise WorkflowError("Multiple builds match the exact app/version/build; refusing ambiguity.")
    if not builds:
        return None
    build = builds[0]
    a = build.get("attributes", {})
    if str(a.get("version")) != build_number:
        raise WorkflowError("Build-number filter returned a different build.")
    owner = relationship(build, "app")
    if owner and owner["id"] != app_id:
        raise WorkflowError("Build belongs to another app.")
    pre = client.request("GET", f"/v1/builds/{build['id']}/preReleaseVersion")["data"]
    if pre["attributes"].get("version") != version or pre["attributes"].get("platform") != platform:
        raise WorkflowError("Build train/platform does not match the requested App Store version.")
    if require_valid and (a.get("processingState") != "VALID" or a.get("expired") is not False):
        raise WorkflowError(f"Build is not ready: processingState={a.get('processingState')}, expired={a.get('expired')}.")
    if require_valid and a.get("buildAudienceType") == "INTERNAL_ONLY":
        raise WorkflowError("An internal-only TestFlight build cannot be submitted to the App Store.")
    return build


def localizations(client: ASCClient, version_id: str) -> dict[str, dict[str, Any]]:
    rows = client.paginate(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations", {"limit": 200})
    result = {r["attributes"]["locale"]: r for r in rows}
    if len(result) != len(rows):
        raise WorkflowError("Duplicate locale records returned by App Store Connect.")
    return result


def review_detail(client: ASCClient, version_id: str) -> dict[str, Any] | None:
    try:
        return client.request("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail").get("data")
    except APIError as error:
        if error.status == 404:
            return None
        raise


def metadata_fingerprint(client: ASCClient, version_id: str) -> str:
    locales = localizations(client, version_id)
    detail = review_detail(client, version_id)
    canonical = {
        "localizations": {locale: {k: row.get("attributes", {}).get(k) for k in FINGERPRINT_FIELDS} for locale, row in locales.items()},
        "reviewNotes": (detail or {}).get("attributes", {}).get("notes"),
    }
    return hashlib.sha256(json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _document(resource_type: str, attributes: dict[str, Any] | None = None, relationships: dict[str, Any] | None = None, resource_id: str | None = None) -> dict[str, Any]:
    data: dict[str, Any] = {"type": resource_type}
    if resource_id:
        data["id"] = resource_id
    if attributes is not None:
        data["attributes"] = attributes
    if relationships:
        data["relationships"] = relationships
    return {"data": data}


def _link(resource_type: str, resource_id: str) -> dict[str, Any]:
    return {"data": {"type": resource_type, "id": resource_id}}


def inspect(client: ASCClient, args: argparse.Namespace) -> dict[str, Any]:
    app = verify_app(client, args.app_id, args.bundle_id)
    versions = client.paginate(f"/v1/apps/{args.app_id}/appStoreVersions", {"filter[platform]": args.platform, "limit": 200})
    builds = client.paginate("/v1/builds", {"filter[app]": args.app_id, "sort": "-uploadedDate", "limit": 200})
    submissions = client.paginate(f"/v1/apps/{args.app_id}/reviewSubmissions", {"limit": 200})
    return {
        "app": {"id": app["id"], "bundleId": app["attributes"]["bundleId"], "name": app["attributes"].get("name")},
        "versions": [{"id": r["id"], "version": r["attributes"]["versionString"], "state": version_state(r), "releaseType": r["attributes"].get("releaseType")} for r in versions],
        "builds": [{"id": r["id"], **{k: r["attributes"].get(k) for k in ("version", "processingState", "expired", "usesNonExemptEncryption", "uploadedDate")}} for r in builds],
        "reviewSubmissions": [{"id": r["id"], **r.get("attributes", {})} for r in submissions],
    }


def prepare(client: ASCClient, args: argparse.Namespace) -> dict[str, Any]:
    verify_app(client, args.app_id, args.bundle_id)
    listing = json.loads(Path(args.listing).read_text())
    notes = Path(args.review_notes).read_text().strip()
    if not isinstance(listing, dict) or not listing or not notes or len(notes) > 4000:
        raise WorkflowError("Provide a nonempty locale listing and review notes of at most 4000 characters.")
    for locale, fields in listing.items():
        if not isinstance(fields, dict) or not re.fullmatch(r"[a-z]{2,3}(?:-[A-Za-z]{2,4})?", locale):
            raise WorkflowError("Invalid locale entry in listing.")
        for field, limit in (("description", 4000), ("whatsNew", 4000), ("promotionalText", 170)):
            if field in fields and (not isinstance(fields[field], str) or len(fields[field]) > limit):
                raise WorkflowError(f"{locale} {field} exceeds its character limit or is not text.")
    build = find_build(client, args.app_id, args.version, args.build, args.platform)
    if not build:
        raise WorkflowError("The exact build is not available yet; upload it and wait for processing before prepare.")
    versions = client.paginate(f"/v1/apps/{args.app_id}/appStoreVersions", {"filter[platform]": args.platform, "limit": 200})
    current = find_version(client, args.app_id, args.version, args.platform)
    prior = sorted((r for r in versions if r["attributes"]["versionString"] != args.version), key=lambda r: r["attributes"].get("createdDate", ""), reverse=True)
    previous = prior[0] if prior else None
    if current and version_state(current) not in EDITABLE_STATES:
        raise WorkflowError(f"Version is {version_state(current)}; do not edit or create another submission.")
    if not current:
        other_drafts = [r for r in prior if version_state(r) in EDITABLE_STATES or version_state(r) in {"WAITING_FOR_REVIEW", "IN_REVIEW"}]
        if other_drafts:
            raise WorkflowError("Another iOS draft/review version exists; inspect it before creating this version.")
        previous_attributes = (previous or {}).get("attributes", {})
        release_type = args.release_type or previous_attributes.get("releaseType") or "MANUAL"
        if release_type == "SCHEDULED":
            raise WorkflowError("Previous release was scheduled; explicitly choose --release-type for this release.")
        attrs = {"platform": args.platform, "versionString": args.version, "releaseType": release_type}
        if previous_attributes.get("copyright"):
            attrs["copyright"] = previous_attributes["copyright"]
        current = client.request("POST", "/v1/appStoreVersions", _document("appStoreVersions", attrs, {"app": _link("apps", args.app_id)}))["data"]
    version_id = current["id"]
    attached = client.request("GET", f"/v1/appStoreVersions/{version_id}/relationships/build").get("data")
    if attached and attached["id"] != build["id"] and not args.replace_build:
        raise WorkflowError("A different build is already attached. Inspect it or explicitly use --replace-build.")
    existing = localizations(client, version_id)
    prior_locales = localizations(client, previous["id"]) if previous else {}
    changes: dict[str, list[str]] = {}
    expected_locales: dict[str, dict[str, Any]] = {}
    for locale, fields in listing.items():
        row = existing.get(locale)
        old_attrs = (row or prior_locales.get(locale) or {}).get("attributes", {})
        wanted = {k: fields[input_key] for k, input_key in (("description", "description"), ("whatsNew", "whatsNew"), ("marketingUrl", "marketingURL"), ("supportUrl", "supportURL"), ("promotionalText", "promotionalText")) if input_key in fields}
        for api_key, source_key in (("supportUrl", "supportURL"), ("promotionalText", "promotionalText")):
            if not row and api_key not in wanted:
                value = old_attrs.get(api_key)
                if value is not None:
                    wanted[api_key] = value
        if args.update_keywords and "keywords" in fields:
            wanted["keywords"] = fields["keywords"]
        elif not row and old_attrs.get("keywords"):
            wanted["keywords"] = old_attrs["keywords"]
        elif not row and fields.get("keywords"):
            if len(fields["keywords"].encode()) > 100:
                raise WorkflowError(f"New locale {locale} has no accepted keywords to inherit and exceeds 100 UTF-8 bytes.")
            wanted["keywords"] = fields["keywords"]
        expected_locales[locale] = dict(wanted)
        if row and not args.update_keywords:
            expected_locales[locale]["keywords"] = old_attrs.get("keywords")
        if row:
            wanted = {k: v for k, v in wanted.items() if old_attrs.get(k) != v}
            if wanted:
                client.request("PATCH", f"/v1/appStoreVersionLocalizations/{row['id']}", _document("appStoreVersionLocalizations", wanted, resource_id=row["id"]))
        else:
            wanted["locale"] = locale
            client.request("POST", "/v1/appStoreVersionLocalizations", _document("appStoreVersionLocalizations", wanted, {"appStoreVersion": _link("appStoreVersions", version_id)}))
        changes[locale] = sorted(wanted)
    detail = review_detail(client, version_id)
    if detail:
        review_changes = {"notes": notes} if detail.get("attributes", {}).get("notes") != notes else {}
        if args.no_demo_account and detail.get("attributes", {}).get("demoAccountRequired") is not False:
            review_changes["demoAccountRequired"] = False
        if review_changes:
            client.request("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", _document("appStoreReviewDetails", review_changes, resource_id=detail["id"]))
    else:
        old_detail = review_detail(client, previous["id"]) if previous else None
        source = (old_detail or {}).get("attributes", {})
        attrs = {k: source[k] for k in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail") if source.get(k)}
        attrs["notes"] = notes
        if args.no_demo_account or source.get("demoAccountRequired") is False:
            attrs["demoAccountRequired"] = False
        client.request("POST", "/v1/appStoreReviewDetails", _document("appStoreReviewDetails", attrs, {"appStoreVersion": _link("appStoreVersions", version_id)}))
    if not attached or attached["id"] != build["id"]:
        client.request("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", _link("builds", build["id"]))
    final = client.request("GET", f"/v1/appStoreVersions/{version_id}")["data"]
    final_build = client.request("GET", f"/v1/appStoreVersions/{version_id}/relationships/build").get("data")
    if not final_build or final_build.get("id") != build["id"]:
        raise WorkflowError("The prepared build attachment did not read back as requested.")
    verified_locales = localizations(client, version_id)
    for locale, expected in expected_locales.items():
        actual = verified_locales.get(locale, {}).get("attributes", {})
        if any(actual.get(key) != value for key, value in expected.items()):
            raise WorkflowError(f"Prepared metadata for {locale} did not read back as requested.")
    if (review_detail(client, version_id) or {}).get("attributes", {}).get("notes") != notes:
        raise WorkflowError("Prepared review notes did not read back as requested.")
    return {
        "status": "PREPARED", "appId": args.app_id, "bundleId": args.bundle_id,
        "platform": args.platform, "version": args.version, "versionId": version_id,
        "build": args.build, "buildId": build["id"], "versionState": version_state(final),
        "releaseType": final.get("attributes", {}).get("releaseType"),
        "metadataSHA256": metadata_fingerprint(client, version_id),
        "localeChanges": changes, "keywordsUpdated": args.update_keywords,
        "encryptionDeclarationMissing": build["attributes"].get("usesNonExemptEncryption") is None,
        "submitted": False,
    }


def declare_encryption(client: ASCClient, args: argparse.Namespace) -> dict[str, Any]:
    verify_app(client, args.app_id, args.bundle_id)
    build = find_build(client, args.app_id, args.version, args.build, args.platform)
    if not build:
        raise WorkflowError("The exact build is not available.")
    value = args.uses_non_exempt_encryption == "true"
    old = build["attributes"].get("usesNonExemptEncryption")
    if old is not None and old != value:
        raise WorkflowError("The build already has a different encryption answer; inspect it rather than overwrite it.")
    if old is None:
        client.request("PATCH", f"/v1/builds/{build['id']}", _document("builds", {"usesNonExemptEncryption": value}, resource_id=build["id"]))
    verified = client.request("GET", f"/v1/builds/{build['id']}")["data"]
    if verified["attributes"].get("usesNonExemptEncryption") != value:
        raise WorkflowError("The encryption declaration did not read back as requested.")
    return {"appId": args.app_id, "version": args.version, "build": args.build, "buildId": build["id"], "usesNonExemptEncryption": value}


def submission_items(client: ASCClient, submission_id: str) -> list[dict[str, Any]]:
    return client.paginate(f"/v1/reviewSubmissions/{submission_id}/items", {
        "include": "appStoreVersion,appAssetLibraryImage,appAssetLibraryVideo", "limit": 200,
    })


def _item_target(item: dict[str, Any]) -> tuple[str, str] | None:
    targets = []
    for value in item.get("relationships", {}).values():
        data = value.get("data")
        if isinstance(data, dict) and data.get("type") != "reviewSubmissions":
            targets.append((data.get("type"), data.get("id")))
    return targets[0] if len(targets) == 1 else None


def submit(client: ASCClient, args: argparse.Namespace) -> dict[str, Any]:
    prepared = json.loads(Path(args.prepared).read_text())
    for name, expected in (("appId", args.app_id), ("bundleId", args.bundle_id), ("version", args.version), ("build", args.build), ("platform", args.platform)):
        if prepared.get(name) != expected:
            raise WorkflowError(f"Prepared receipt does not match the requested {name}.")
    verify_app(client, args.app_id, args.bundle_id)
    version = find_version(client, args.app_id, args.version, args.platform)
    if not version or version["id"] != prepared.get("versionId"):
        raise WorkflowError("The prepared App Store version no longer matches.")
    build = find_build(client, args.app_id, args.version, args.build, args.platform)
    if not build or build["id"] != prepared.get("buildId"):
        raise WorkflowError("The prepared build no longer matches.")
    attached = client.request("GET", f"/v1/appStoreVersions/{version['id']}/relationships/build").get("data")
    if not attached or attached["id"] != build["id"]:
        raise WorkflowError("The exact prepared build is not attached.")
    submissions = client.paginate(f"/v1/apps/{args.app_id}/reviewSubmissions", {"limit": 200})
    relevant = [s for s in submissions if s.get("attributes", {}).get("platform") in (None, args.platform)]
    target = ("appStoreVersions", version["id"])
    with_items = [(s, submission_items(client, s["id"])) for s in relevant]
    matches = [(s, items) for s, items in with_items if target in [_item_target(i) for i in items] and s.get("attributes", {}).get("state") != "COMPLETE"]
    if len(matches) > 1:
        raise WorkflowError("The version appears in multiple active submissions; inspect before proceeding.")
    if matches and matches[0][0]["attributes"].get("state") in SUBMITTED_STATES:
        return _submission_receipt(args, version, build, matches[0][0], already=True)
    if version_state(version) in FINISHED_VERSION_STATES:
        return {"status": "ALREADY_ACCEPTED_OR_RELEASED", "versionId": version["id"], "versionState": version_state(version), "submitted": True}
    if version_state(version) not in EDITABLE_STATES:
        raise WorkflowError(f"Version state {version_state(version)} cannot be submitted by this workflow.")
    if build["attributes"].get("usesNonExemptEncryption") is None:
        raise WorkflowError("Build encryption answer is missing. Use the explicit declare-encryption command after confirming the appropriate answer.")
    if metadata_fingerprint(client, version["id"]) != prepared.get("metadataSHA256"):
        raise WorkflowError("Metadata changed after prepare. Review the changes and run prepare again before submitting.")
    # This workflow submits the specified app version only. It must never sweep
    # unrelated IAP/events/experiments into review simply because a draft exists.
    if matches:
        submission, items = matches[0]
        if submission["attributes"].get("state") != "READY_FOR_REVIEW":
            raise WorkflowError("Existing submission has unresolved/canceling state; resolve it explicitly first.")
        if len(items) != 1 or _item_target(items[0]) != target:
            raise WorkflowError("Existing submission contains additional items; this version-only command will not submit them.")
    else:
        active = [(s, items) for s, items in with_items if s.get("attributes", {}).get("state") != "COMPLETE"]
        if len(active) > 1 or (active and (active[0][1] or active[0][0]["attributes"].get("state") != "READY_FOR_REVIEW")):
            raise WorkflowError("Another active submission exists; refusing to add or submit unrelated items.")
        if active:
            submission, _ = active[0]
        else:
            submission = client.request("POST", "/v1/reviewSubmissions", _document("reviewSubmissions", {"platform": args.platform}, {"app": _link("apps", args.app_id)}))["data"]
        client.request("POST", "/v1/reviewSubmissionItems", _document("reviewSubmissionItems", relationships={
            "reviewSubmission": _link("reviewSubmissions", submission["id"]),
            "appStoreVersion": _link("appStoreVersions", version["id"]),
        }))
    items = submission_items(client, submission["id"])
    if len(items) != 1 or _item_target(items[0]) != target:
        raise WorkflowError("Final submission contents do not match the exact app version.")
    final_build = client.request("GET", f"/v1/appStoreVersions/{version['id']}/relationships/build").get("data")
    if not final_build or final_build.get("id") != build["id"] or metadata_fingerprint(client, version["id"]) != prepared.get("metadataSHA256"):
        raise WorkflowError("Build or metadata changed while preparing submission. Inspect and prepare again.")
    client.request("PATCH", f"/v1/reviewSubmissions/{submission['id']}", _document("reviewSubmissions", {"submitted": True}, resource_id=submission["id"]))
    for attempt in range(11):
        verified = client.request("GET", f"/v1/reviewSubmissions/{submission['id']}")["data"]
        if verified.get("attributes", {}).get("state") in SUBMITTED_STATES:
            return _submission_receipt(args, version, build, verified, already=False)
        if verified.get("attributes", {}).get("state") not in ("READY_FOR_REVIEW",):
            raise WorkflowError(f"Submission returned state {verified.get('attributes', {}).get('state')}; inspect before retrying.")
        if attempt < 10:
            time.sleep(3)
    raise WorkflowError("Submission write completed but WAITING_FOR_REVIEW was not observed. Inspect state before retrying.")


def _submission_receipt(args: argparse.Namespace, version: dict[str, Any], build: dict[str, Any], submission: dict[str, Any], already: bool) -> dict[str, Any]:
    return {
        "appId": args.app_id, "version": args.version, "versionId": version["id"],
        "build": args.build, "buildId": build["id"], "submissionId": submission["id"],
        "status": submission["attributes"]["state"], "submitted": True,
        "alreadySubmitted": already, "submittedDate": submission["attributes"].get("submittedDate"),
        "url": f"https://appstoreconnect.apple.com/apps/{args.app_id}/distribution/reviewsubmissions/details/{submission['id']}",
    }


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--config", help="Private local API config JSON path (or ASC_CONFIG).")
    p.add_argument("--app-id", default=DEFAULT_APP_ID)
    p.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    p.add_argument("--platform", choices=("IOS", "MAC_OS", "TV_OS", "VISION_OS"), default="IOS")
    p.add_argument("--version", default="1.06")
    p.add_argument("--build", default="66")
    commands = p.add_subparsers(dest="command", required=True)
    read = commands.add_parser("inspect", help="Read app identity, versions, builds and submission states.")
    read.add_argument("--output")
    prep = commands.add_parser("prepare", help="Create/update the exact draft and attach its validated build; never submits.")
    prep.add_argument("--listing", required=True)
    prep.add_argument("--review-notes", required=True)
    prep.add_argument("--output", required=True, help="Write preparation receipt for later submit.")
    prep.add_argument("--release-type", choices=("MANUAL", "AFTER_APPROVAL"), help="For a new draft only; otherwise inherit previous release behavior.")
    prep.add_argument("--update-keywords", action="store_true", help="Explicitly replace keywords; default preserves accepted server values.")
    prep.add_argument("--replace-build", action="store_true", help="Allow replacing a different attached build after inspection.")
    prep.add_argument("--no-demo-account", action="store_true", help="Explicitly set demoAccountRequired=false for this account-free app.")
    submit_parser = commands.add_parser("submit", help="Submit only the exact prepared version; verify its resulting state.")
    submit_parser.add_argument("--prepared", required=True)
    submit_parser.add_argument("--output", required=True)
    declaration = commands.add_parser("declare-encryption", help="Apply an explicitly chosen build encryption answer; not inferred automatically.")
    declaration.add_argument("--uses-non-exempt-encryption", choices=("true", "false"), required=True)
    declaration.add_argument("--output")
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        client = ASCClient(AuthConfig.load(args.config))
        result = {"inspect": inspect, "prepare": prepare, "submit": submit, "declare-encryption": declare_encryption}[args.command](client, args)
        encoded = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        if args.output:
            path = Path(args.output)
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_name(path.name + ".tmp")
            temp.write_text(encoded)
            temp.replace(path)
        print(encoded, end="")
        return 0
    except (WorkflowError, OSError, ValueError, KeyError) as error:
        # Do not emit raw request headers, private config content, or a traceback.
        result = {"ok": False, "error": str(error)}
        if isinstance(error, APIError):
            result.update(httpStatus=error.status, code=error.code)
        print(json.dumps(result, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
