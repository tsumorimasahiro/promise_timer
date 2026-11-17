#!/usr/bin/env python3
"""Offline ASC submission/media regression tests; no credentials or network needed.

The clients below are in-memory server models. API writes only mutate those
models. Temporary journals are created outside the repository and removed.
"""

import argparse, copy, io, json, pathlib, sys, tempfile, unittest
from unittest.mock import Mock, call, patch
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import app_store_connect as asc
import app_store_media as media
NETWORK_GUARD = patch('socket.create_connection', side_effect=AssertionError('Regression tests must not use the network.'))

def setUpModule():
    NETWORK_GUARD.start()

def tearDownModule():
    NETWORK_GUARD.stop()

class SubmissionClient:

    def __init__(self):
        self.writes = []
        self.version = {'id': 'v1', 'attributes': {'versionString': '1.06', 'platform': 'IOS', 'appVersionState': 'PREPARE_FOR_SUBMISSION'}}
        self.build = {'id': 'b66', 'attributes': {'version': '66', 'processingState': 'VALID', 'expired': False, 'usesNonExemptEncryption': False}, 'relationships': {'app': {'data': {'type': 'apps', 'id': '6760613210'}}}}
        self.attached = {'type': 'builds', 'id': 'b66'}
        self.submissions = []
        self.items = {}

    def paginate(self, path, params=None):
        if path.endswith('/appStoreVersions'):
            return [self.version]
        if path == '/v1/builds':
            return [self.build]
        if path.endswith('/reviewSubmissions'):
            return self.submissions
        if path.endswith('/items'):
            return self.items[path.split('/')[-2]]
        if path.endswith('/appStoreVersionLocalizations'):
            return []
        raise AssertionError(path)

    def request(self, method, path, data=None, params=None):
        if method != 'GET':
            self.writes.append((method, path, data))
        if method == 'GET':
            if path == '/v1/apps/6760613210':
                return {'data': {'id': '6760613210', 'attributes': {'bundleId': 'max.promise-timer'}}}
            if path.endswith('/preReleaseVersion'):
                return {'data': {'attributes': {'version': '1.06', 'platform': 'IOS'}}}
            if path.endswith('/relationships/build'):
                return {'data': self.attached}
            if path.endswith('/appStoreReviewDetail'):
                return {'data': None}
            if path.startswith('/v1/reviewSubmissions/'):
                return {'data': next((s for s in self.submissions if s['id'] == path.rsplit('/', 1)[1]))}
        if method == 'POST' and path == '/v1/reviewSubmissions':
            s = {'type': 'reviewSubmissions', 'id': 's1', 'attributes': {'platform': 'IOS', 'state': 'READY_FOR_REVIEW'}}
            self.submissions.append(s)
            self.items['s1'] = []
            return {'data': s}
        if method == 'POST' and path == '/v1/reviewSubmissionItems':
            s = data['data']['relationships']['reviewSubmission']['data']['id']
            self.items[s].append({'id': 'item1', **data['data']})
            return {'data': self.items[s][-1]}
        if method == 'PATCH' and path.startswith('/v1/reviewSubmissions/'):
            s = next((s for s in self.submissions if s['id'] == path.rsplit('/', 1)[1]))
            s['attributes']['state'] = 'WAITING_FOR_REVIEW'
            return {'data': s}
        raise AssertionError((method, path, data))

class SubmissionTest(unittest.TestCase):

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.c = SubmissionClient()
        self.receipt = {'appId': '6760613210', 'bundleId': 'max.promise-timer', 'version': '1.06', 'build': '66', 'platform': 'IOS', 'versionId': 'v1', 'buildId': 'b66', 'metadataSHA256': asc.metadata_fingerprint(self.c, 'v1')}
        p = pathlib.Path(self.temp.name) / 'prepared.json'
        p.write_text(json.dumps(self.receipt))
        self.args = argparse.Namespace(app_id='6760613210', bundle_id='max.promise-timer', version='1.06', build='66', platform='IOS', prepared=str(p))

    def test_submission_success_and_repeat_zero_new_mutations(self):
        first = asc.submit(self.c, self.args)
        n = len(self.c.writes)
        second = asc.submit(self.c, self.args)
        self.assertEqual(first['status'], 'WAITING_FOR_REVIEW')
        self.assertTrue(second['alreadySubmitted'])
        self.assertEqual(len(self.c.writes), n)

    def test_wrong_attached_build_blocks_before_writes(self):
        self.c.attached['id'] = 'b65'
        with self.assertRaises(asc.WorkflowError):
            asc.submit(self.c, self.args)
        self.assertFalse(self.c.writes)

    def test_missing_encryption_blocks_before_writes(self):
        self.c.build['attributes']['usesNonExemptEncryption'] = None
        with self.assertRaises(asc.WorkflowError):
            asc.submit(self.c, self.args)
        self.assertFalse(self.c.writes)

    def test_wrong_app_build_blocks_before_writes(self):
        self.c.build['relationships']['app']['data']['id'] = 'another-app'
        with self.assertRaises(asc.WorkflowError):
            asc.submit(self.c, self.args)
        self.assertFalse(self.c.writes)

    def test_processing_build_blocks_before_writes(self):
        self.c.build['attributes']['processingState'] = 'PROCESSING'
        with self.assertRaises(asc.WorkflowError):
            asc.submit(self.c, self.args)
        self.assertFalse(self.c.writes)

    def test_mixed_submission_items_blocks(self):
        self.c.submissions = [{'id': 's1', 'attributes': {'platform': 'IOS', 'state': 'READY_FOR_REVIEW'}}]
        self.c.items = {'s1': [{'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': 'v1'}}}}, {'relationships': {'appEvent': {'data': {'type': 'appEvents', 'id': 'unrelated'}}}}]}
        with self.assertRaises(asc.WorkflowError):
            asc.submit(self.c, self.args)
        self.assertFalse(self.c.writes)

    def test_ambiguous_write_not_retried(self):

        class BrokenOpener:
            count = 0

            def open(s, *args, **kw):
                s.count += 1
                raise asc.URLError('opaque')
        client = asc.ASCClient(asc.AuthConfig('fake', pathlib.Path('/unused'), 'fake'))
        client._token = 'synthetic-token'
        client._token_created = asc.time.time()
        client._opener = BrokenOpener()
        with self.assertRaisesRegex(asc.WorkflowError, 'Inspect server state'):
            client.request('POST', '/v1/reviewSubmissions', {})
        self.assertEqual(client._opener.count, 1)

    def test_foreign_origin_blocked(self):
        client = asc.ASCClient(asc.AuthConfig('fake', pathlib.Path('/unused'), 'fake'))
        with self.assertRaisesRegex(asc.WorkflowError, 'only sends credentials'):
            client.request('GET', 'https://api.appstoreconnect.apple.com.attacker.invalid/v1/apps')

class HTTPClientTest(unittest.TestCase):

    def test_nested_associated_errors_show_missing_fields_without_raw_meta(self):
        error = asc.APIError(409, [{
            'code': 'ENTITY_ERROR', 'title': 'Cannot add item', 'detail': 'Required data is missing.',
            'meta': {
                'authorization': 'arbitrary-meta-secret',
                'associatedErrors': {'https://private-resource.invalid/should-not-print': [{
                    'code': 'ENTITY_ERROR.REQUIRED', 'title': 'Missing age rating',
                    'detail': 'socialMedia is required.',
                    'source': {'pointer': '/data/attributes/socialMedia', 'unlisted': 'source-secret'},
                    'meta': {'associatedErrors': [{
                        'code': 'ENTITY_ERROR.REQUIRED',
                        'detail': 'socialMediaAgeRestricted is required.',
                    }]},
                }]},
            },
        }])
        text = str(error)
        self.assertEqual(error.code, 'ENTITY_ERROR')
        self.assertIn('App Store Connect HTTP 409', text)
        self.assertIn('socialMedia is required.', text)
        self.assertIn('source.pointer=/data/attributes/socialMedia', text)
        self.assertIn('socialMediaAgeRestricted is required.', text)
        for secret in ('arbitrary-meta-secret', 'private-resource.invalid', 'source-secret'):
            self.assertNotIn(secret, text)

    def test_nested_associated_errors_keep_credential_redaction(self):
        jwt = 'eyJhbGciOiJFUzI1NiJ9.eyJhdWQiOiJ0ZXN0In0.c2lnbmF0dXJl'
        private_key = '-----BEGIN PRIVATE KEY-----\nSYNTHETIC-PRIVATE-DATA\n-----END PRIVATE KEY-----'
        text = str(asc.APIError(409, [{
            'code': 'ENTITY_ERROR',
            'meta': {'associatedErrors': [{
                'code': 'NESTED', 'detail': jwt + ' ' + private_key,
            }]},
        }]))
        self.assertIn('[JWT redacted]', text)
        self.assertIn('[key redacted]', text)
        self.assertNotIn(jwt, text)
        self.assertNotIn('SYNTHETIC-PRIVATE-DATA', text)

    def client(self, responses):
        client = asc.ASCClient(asc.AuthConfig('fake', pathlib.Path('/unused'), 'fake'))
        client._token = 'synthetic-token'
        client._token_created = asc.time.time()
        client._opener = Mock()
        client._opener.open.side_effect = responses
        return client

    def test_get_recovers_from_transient_network_failure(self):
        client = self.client([asc.URLError('temporary connection failure'), io.BytesIO(b'{"data": []}')])
        with patch.object(asc.time, 'sleep') as sleep:
            self.assertEqual(client.request('GET', '/v1/apps'), {'data': []})
        self.assertEqual(client._opener.open.call_count, 2)
        self.assertEqual(sleep.call_args_list, [call(1)])

    def test_get_recovers_from_timeout_with_bounded_backoff(self):
        client = self.client([TimeoutError('temporary timeout'), TimeoutError('temporary timeout'), io.BytesIO(b'{"data": []}')])
        with patch.object(asc.time, 'sleep') as sleep:
            self.assertEqual(client.request('GET', '/v1/apps'), {'data': []})
        self.assertEqual(client._opener.open.call_count, 3)
        self.assertEqual(sleep.call_args_list, [call(1), call(2)])

    def test_get_stops_after_three_failed_network_attempts(self):
        client = self.client([asc.URLError('unavailable')] * 3)
        with patch.object(asc.time, 'sleep') as sleep:
            with self.assertRaisesRegex(asc.WorkflowError, 'after 3 attempts'):
                client.request('GET', '/v1/apps')
        self.assertEqual(client._opener.open.call_count, 3)
        self.assertEqual(sleep.call_args_list, [call(1), call(2)])

    def test_network_failures_never_retry_mutations(self):
        for method in ('POST', 'PATCH', 'DELETE'):
            for failure in (asc.URLError('connection failed'), TimeoutError('timeout'), OSError('connection reset')):
                with self.subTest(method=method, failure=type(failure).__name__):
                    client = self.client([failure])
                    with patch.object(asc.time, 'sleep') as sleep:
                        with self.assertRaisesRegex(asc.WorkflowError, 'Inspect server state'):
                            client.request(method, '/v1/reviewSubmissions', {})
                    self.assertEqual(client._opener.open.call_count, 1)
                    sleep.assert_not_called()

class MediaClient:

    def __init__(self, assets):
        self.writes = []
        self.asset_resources = {}
        self.placements = {}
        for (n, a) in enumerate(assets):
            self.asset_resources[a['reference_name']] = {'id': f'a{n}', 'type': a['type'], 'attributes': {'referenceName': a['reference_name'], 'fileSize': a['size'], 'state': 'COMPLETE', 'specId': 'spec'}, 'relationships': {}}
        self.placements['ja'] = [self.make_placement('old-ja', 'APP_SCREENSHOT', 'oldimage'), self.make_placement('keep-video', 'APP_PREVIEW', None, 'keepvideo')]
        self.placements['en-US'] = [self.make_placement('old-en', 'APP_SCREENSHOT', 'oldimage-en')]

    def make_placement(self, id, kind, image=None, video=None):
        return {'id': id, 'type': 'appAssetLibraryPlacements', 'attributes': {'placementType': kind, 'placementGroup': 'group', 'state': 'PARENT_PREPARE_FOR_SUBMISSION'}, 'relationships': {'image': {'data': {'type': 'appAssetLibraryImages', 'id': image} if image else None}, 'video': {'data': {'type': 'appAssetLibraryVideos', 'id': video} if video else None}}}

    def paginate(self, path, params=None):
        if '/appAssetLibraries/' in path:
            r = self.asset_resources.get(params['filter[referenceName]'])
            return [r] if r else []
        if '/appStoreVersionLocalizations/' in path:
            result = copy.deepcopy(self.placements[path.split('/')[-2]])
            placement_type = (params or {}).get('filter[placementType]')
            return [p for p in result if not placement_type or p['attributes']['placementType'] == placement_type]
        raise AssertionError(path)

    def request(self, method, path, data=None, params=None):
        if method != 'GET':
            self.writes.append((method, path, data))
        if method == 'GET':
            if path == '/v1/appStoreVersions/v1':
                return {'data': {'attributes': {'appVersionState': 'PREPARE_FOR_SUBMISSION'}}}
            if '/appAssetLibraryImages/' in path:
                return {'data': copy.deepcopy(next((r for r in self.asset_resources.values() if r['id'] == path.rsplit('/', 1)[1])))}
            if '/appAssetLibraryPlacements/' in path:
                return {'data': copy.deepcopy(next((p for row in self.placements.values() for p in row if p['id'] == path.rsplit('/', 1)[1])))}
        if method == 'POST' and path == '/v1/appAssetLibraryPlacements':
            r = data['data']
            loc = r['relationships']['appStoreVersionLocalization']['data']['id']
            aid = r['relationships']['image']['data']['id']
            p = self.make_placement('new-' + aid, r['attributes']['placementType'], aid)
            self.placements[loc].append(p)
            return {'data': copy.deepcopy(p)}
        if method == 'POST' and path == '/v1/appAssetLibraryPlacementOrderingRequests':
            r = data['data']['relationships']
            loc = r['appStoreVersionLocalization']['data']['id']
            ids = [p['id'] for p in r['orderedPlacements']['data']]
            by_id = {p['id']: p for p in self.placements[loc]}
            types = {by_id[i]['attributes']['placementType'] for i in ids}
            if len(types) != 1:
                raise AssertionError('Apple rejects mixed placement types in ordering requests')
            placement_type = types.pop()
            existing = {p['id'] for p in self.placements[loc] if p['attributes']['placementType'] == placement_type}
            if set(ids) != existing:
                raise AssertionError('Ordering must preserve every placement of the target type')
            ordered = iter(by_id[i] for i in ids)
            self.placements[loc] = [next(ordered) if p['attributes']['placementType'] == placement_type else p
                                    for p in self.placements[loc]]
            return {'data': {'id': 'order'}}
        if method == 'DELETE' and path.startswith('/v1/appAssetLibraryPlacements/'):
            id = path.rsplit('/', 1)[1]
            for loc in self.placements:
                self.placements[loc] = [p for p in self.placements[loc] if p['id'] != id]
            return {}
        raise AssertionError((method, path, data))

class ProcessingMediaClient(MediaClient):
    """Apple processing completes after the uploader commits the full batch."""

    def __init__(self, assets):
        super().__init__(assets)
        self.committed = set()
        self.ready = set()
        for resource in self.asset_resources.values():
            resource['attributes'].update(state='AWAITING_UPLOAD', specId=None,
                                          uploadOperations=[{'synthetic': True}])

    def request(self, method, path, data=None, params=None):
        if '/appAssetLibraryImages/' in path:
            asset_id = path.rsplit('/', 1)[-1]
            resource = next(r for r in self.asset_resources.values() if r['id'] == asset_id)
            if method == 'PATCH':
                self.writes.append((method, path, data))
                self.committed.add(asset_id)
                resource['attributes']['state'] = 'UPLOAD_COMPLETE'
                return {'data': copy.deepcopy(resource)}
            if method == 'GET' and resource['attributes']['state'] == 'UPLOAD_COMPLETE':
                if len(self.committed) != len(self.asset_resources):
                    raise AssertionError('Processing poll ran before every transfer was committed')
                resource['attributes'].update(state='PREPARE_FOR_SUBMISSION', specId='spec')
                self.ready.add(asset_id)
        if method == 'POST' and path == '/v1/appAssetLibraryPlacements':
            if len(self.ready) != len(self.asset_resources):
                raise AssertionError('Placement changed before full batch readiness')
        return super().request(method, path, data, params)


class MediaTest(unittest.TestCase):

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.assets = [{'key': loc + '/APP_SCREENSHOT/01.png', 'locale': loc, 'placement_type': 'APP_SCREENSHOT', 'type': 'appAssetLibraryImages', 'reference_name': loc + '-hash', 'sha256': loc + '-hash', 'size': 5, 'allowed_spec_ids': ['spec']} for loc in ['ja', 'en-US']]
        self.scope = {'app_id': '6760613210', 'version': '1.06', 'version_id': 'v1', 'library_id': 'lib', 'placement_group': 'group', 'locale_ids': {'ja': 'ja', 'en-US': 'en-US'}, 'limits': {'APP_SCREENSHOT': 10, 'APP_PREVIEW': 3}}
        self.c = MediaClient(self.assets)
        self.state = media.State(pathlib.Path(self.temp.name) / 'state.json', self.scope, self.assets)
        self.args = argparse.Namespace(timeout=1, poll_interval=1)

    def test_fullflow_preserves_other_types_and_repeat_idempotent(self):
        result = media.upload(self.c, self.scope, self.assets, self.state, self.args)
        self.assertTrue(result['complete'])
        self.assertEqual([p['id'] for p in self.c.placements['ja'] if p['attributes']['placementType'] == 'APP_SCREENSHOT'], ['new-a0'])
        self.assertEqual([p['id'] for p in self.c.placements['ja'] if p['attributes']['placementType'] == 'APP_PREVIEW'], ['keep-video'])
        n = len(self.c.writes)
        media.upload(self.c, self.scope, self.assets, self.state, self.args)
        self.assertEqual(len(self.c.writes), n)
        deletes = [p for (m, p, d) in self.c.writes if m == 'DELETE']
        self.assertEqual(set(deletes), {'/v1/appAssetLibraryPlacements/old-ja', '/v1/appAssetLibraryPlacements/old-en'})

    def test_bad_asset_state_prevents_placement_mutation(self):
        self.c.asset_resources['en-US-hash']['attributes']['state'] = 'FAILED'
        with self.assertRaises(media.MediaError):
            media.upload(self.c, self.scope, self.assets, self.state, self.args)
        self.assertFalse(self.c.writes)

    def test_added_concurrent_placement_preserved_and_blocked(self):
        media.preflight(self.c, self.scope, self.assets, self.state)
        self.c.placements['ja'].append(self.c.make_placement('external', 'APP_SCREENSHOT', 'external-image'))
        with self.assertRaises(media.MediaError):
            media.upload(self.c, self.scope, self.assets, self.state, self.args)
        self.assertFalse(self.c.writes)

    def test_asset_scope_mismatch_resume_rejected(self):
        self.state.save()
        changed = copy.deepcopy(self.scope)
        changed['version_id'] = 'another'
        with self.assertRaises(media.MediaError):
            media.State(self.state.path, changed, self.assets)

    def test_ready_asset_waits_for_spec_without_reupload(self):
        # Live ASC can report a ready state before its processed specId appears.
        original_request = self.c.request
        reads = []

        def delayed_spec(method, path, data=None, params=None):
            reads.append((method, path))
            response = original_request(method, path, data, params)
            if len(reads) == 1:
                response['data']['attributes']['specId'] = None
            return response

        with patch.object(self.c, 'request', side_effect=delayed_spec), patch.object(media.time, 'sleep'):
            result = media.ensure_asset(self.c, self.scope, self.assets[0], self.state, self.args)
        self.assertEqual(result['id'], 'a0')
        self.assertEqual(result['attributes']['specId'], 'spec')
        self.assertEqual(reads, [('GET', '/v1/appAssetLibraryImages/a0')] * 2)
        self.assertFalse(self.c.writes)

    def test_ready_asset_with_wrong_spec_blocks_placement_changes(self):
        self.c.asset_resources['ja-hash']['attributes']['specId'] = 'incompatible-spec'
        with self.assertRaisesRegex(media.MediaError, 'unexpected specification'):
            media.ensure_asset(self.c, self.scope, self.assets[0], self.state, self.args)
        self.assertFalse(self.c.writes)

    def test_ready_asset_missing_spec_has_bounded_wait(self):
        self.c.asset_resources['ja-hash']['attributes']['specId'] = None
        with patch.object(media.time, 'monotonic', side_effect=[0, 2]):
            with self.assertRaisesRegex(media.MediaError, 'Timed out'):
                media.ensure_asset(self.c, self.scope, self.assets[0], self.state, self.args)
        self.assertFalse(self.c.writes)

    def test_ordering_visibility_delay_retries_reads_without_second_write(self):
        self.c.placements['ja'].append(self.c.make_placement('second-ja', 'APP_SCREENSHOT', 'second-image'))
        original_paginate = self.c.paginate
        stale = [copy.deepcopy(p) for p in self.c.placements['ja'] if p['attributes']['placementType'] == 'APP_SCREENSHOT']
        reads = []

        def delayed_order(path, params=None):
            if (params or {}).get('filter[placementType]') == 'APP_SCREENSHOT':
                reads.append(path)
                if len(reads) == 1:
                    return stale
            return original_paginate(path, params)

        desired = ['keep-video', 'second-ja', 'old-ja']
        with patch.object(self.c, 'paginate', side_effect=delayed_order), patch.object(media.time, 'sleep'):
            media.order_group(self.c, self.scope, 'ja', desired)
        self.assertEqual([p['id'] for p in self.c.placements['ja'] if p['attributes']['placementType'] == 'APP_SCREENSHOT'], ['second-ja', 'old-ja'])
        self.assertEqual(len(reads), 2)
        self.assertEqual([(method, path) for method, path, _ in self.c.writes], [
            ('POST', '/v1/appAssetLibraryPlacementOrderingRequests')])

    def test_unconfirmed_ordering_stops_without_repeating_write(self):
        self.c.placements['ja'].append(self.c.make_placement('second-ja', 'APP_SCREENSHOT', 'second-image'))
        stale = copy.deepcopy(self.c.placements['ja'])

        def stale_order(path, params=None):
            placement_type = (params or {}).get('filter[placementType]')
            return [p for p in stale if not placement_type or p['attributes']['placementType'] == placement_type]

        with patch.object(self.c, 'paginate', side_effect=stale_order) as reads, patch.object(media.time, 'sleep'):
            with self.assertRaisesRegex(media.MediaError, 'ordering has not been confirmed'):
                media.order_group(self.c, self.scope, 'ja', ['keep-video', 'second-ja', 'old-ja'])
        self.assertEqual(reads.call_count, 7)
        self.assertEqual([(method, path) for method, path, _ in self.c.writes], [
            ('POST', '/v1/appAssetLibraryPlacementOrderingRequests')])

    def test_ordering_partitions_screenshots_and_previews_in_one_group(self):
        self.c.placements['ja'].extend([
            self.c.make_placement('second-ja', 'APP_SCREENSHOT', 'second-image'),
            self.c.make_placement('second-video', 'APP_PREVIEW', None, 'second-video-asset')])
        desired = ['second-video', 'second-ja', 'keep-video', 'old-ja']
        media.order_group(self.c, self.scope, 'ja', desired)
        ordered_requests = [data['data']['relationships']['orderedPlacements']['data']
                            for method, path, data in self.c.writes]
        self.assertEqual([[p['id'] for p in row] for row in ordered_requests],
                         [['second-video', 'keep-video'], ['second-ja', 'old-ja']])
        self.assertEqual([p['id'] for p in media.placements(self.c, self.scope, 'ja', 'APP_PREVIEW')],
                         ['second-video', 'keep-video'])
        self.assertEqual([p['id'] for p in media.placements(self.c, self.scope, 'ja', 'APP_SCREENSHOT')],
                         ['second-ja', 'old-ja'])
        writes = len(self.c.writes)
        media.order_group(self.c, self.scope, 'ja', desired)
        self.assertEqual(len(self.c.writes), writes)

    def test_ordering_rejects_missing_or_unknown_ids_before_writes(self):
        for ids in (['old-ja'], ['old-ja', 'foreign-placement'], ['old-ja', 'old-ja', 'keep-video']):
            with self.subTest(ids=ids), self.assertRaises(media.MediaError):
                media.order_group(self.c, self.scope, 'ja', ids)
        self.assertFalse(self.c.writes)

    def test_every_transfer_committed_before_any_processing_poll(self):
        self.c = ProcessingMediaClient(self.assets)
        with patch.object(media, 'upload_parts') as transfer:
            result = media.upload(self.c, self.scope, self.assets, self.state, self.args)
        self.assertTrue(result['complete'])
        self.assertEqual(transfer.call_count, 2)
        self.assertEqual(len(self.c.committed), 2)
        self.assertEqual(len(self.c.ready), 2)
        writes = len(self.c.writes)
        with patch.object(media, 'upload_parts') as transfer:
            media.upload(self.c, self.scope, self.assets, self.state, self.args)
        self.assertEqual(len(self.c.writes), writes)
        transfer.assert_not_called()

    def test_stale_collection_never_reuploads_committed_asset(self):
        self.c.asset_resources['ja-hash']['attributes']['state'] = 'AWAITING_UPLOAD'
        original_request = self.c.request

        def fresh_resource(method, path, data=None, params=None):
            response = original_request(method, path, data, params)
            if '/appAssetLibraryImages/' in path:
                response['data']['attributes']['state'] = 'UPLOAD_COMPLETE'
            return response

        with patch.object(self.c, 'request', side_effect=fresh_resource), patch.object(media, 'upload_parts') as transfer:
            result = media.stage_asset(self.c, self.scope, self.assets[0], self.state)
        self.assertEqual(result['attributes']['state'], 'UPLOAD_COMPLETE')
        self.assertFalse(self.c.writes)
        transfer.assert_not_called()

    def active_placement(self):
        media.stage_asset(self.c, self.scope, self.assets[0], self.state)
        placement = self.c.make_placement('active-placement', 'APP_SCREENSHOT', 'a0')
        placement['attributes'].update(state='ACTIVE', stateDetails=None, mediaType='IMAGE')
        placement['relationships']['appStoreVersionLocalization'] = {'data': {'type': 'appStoreVersionLocalizations', 'id': 'ja'}}
        self.c.placements['ja'].append(placement)
        return placement

    def test_active_placement_requires_ready_asset_and_scoped_parent(self):
        placement = self.active_placement()
        # The API may omit direct parent linkage. Its scoped collection still
        # proves which localization owns this placement.
        del placement['relationships']['appStoreVersionLocalization']
        result = media.wait_for_placement(self.c, self.scope, self.assets[0], self.state,
                                          self.args, placement['id'])
        self.assertEqual(result['id'], placement['id'])
        self.assertEqual(self.state.data['assets'][self.assets[0]['key']]['state'], 'COMPLETE')
        self.assertFalse(self.c.writes)

    def test_active_placement_rejects_inconsistent_asset_or_target(self):
        placement = self.active_placement()
        original = copy.deepcopy(placement)
        changes = [
            ('placementGroup', 'another-group'), ('placementType', 'APP_PREVIEW'),
            ('mediaType', 'VIDEO'), ('stateDetails', {'errors': ['processing failed']}),
            ('image', 'another-asset'), ('appStoreVersionLocalization', 'another-locale')]
        for field, value in changes:
            with self.subTest(field=field):
                placement.clear()
                placement.update(copy.deepcopy(original))
                if field in ('image', 'appStoreVersionLocalization'):
                    placement['relationships'][field]['data']['id'] = value
                else:
                    placement['attributes'][field] = value
                with self.assertRaises(media.MediaError):
                    media.wait_for_placement(self.c, self.scope, self.assets[0], self.state,
                                             self.args, placement['id'])
        self.assertFalse(self.c.writes)

    def test_active_placement_cannot_override_failed_asset(self):
        placement = self.active_placement()
        self.c.asset_resources['ja-hash']['attributes']['state'] = 'FAILED'
        with self.assertRaisesRegex(media.MediaError, 'processing failed'):
            media.wait_for_placement(self.c, self.scope, self.assets[0], self.state,
                                     self.args, placement['id'])
        self.assertFalse(self.c.writes)

    def test_unknown_placement_state_is_not_treated_as_active(self):
        placement = self.active_placement()
        placement['attributes']['state'] = 'UNDOCUMENTED_OTHER_STATE'
        with patch.object(media.time, 'monotonic', side_effect=[0, 2]):
            with self.assertRaisesRegex(media.MediaError, 'Timed out'):
                media.wait_for_placement(self.c, self.scope, self.assets[0], self.state,
                                         self.args, placement['id'])
        self.assertFalse(self.c.writes)

if __name__ == '__main__':
    unittest.main(verbosity=2)
