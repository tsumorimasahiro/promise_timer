#!/usr/bin/env python3
"""Distribute only to the verified sole account holder. Never submits App Review."""
import argparse
import json
from pathlib import Path
from app_store_connect import ASCClient, AuthConfig, WorkflowError, verify_app, find_build

APP = '6760613210'
BUNDLE = 'max.promise-timer'
GROUP = 'Owner only'


def owner_only(users):
    owners = [u for u in users if 'ACCOUNT_HOLDER' in u['attributes'].get('roles', [])]
    if len(owners) != 1 or len(users) != 1:
        raise WorkflowError('Expected the sole account user to be the account holder; inspect recipients manually.')
    return owners[0]['attributes']


def check_group(group, members, email):
    attrs = group['attributes']
    if not attrs.get('isInternalGroup') or attrs.get('publicLinkEnabled') or attrs.get('hasAccessToAllBuilds'):
        raise WorkflowError('Owner group must be internal, private, and manually distributed.')
    if any(t['attributes'].get('email', '').lower() != email.lower() for t in members):
        raise WorkflowError('Owner group contains another tester; refusing distribution.')


def run(c, args):
    verify_app(c, APP, BUNDLE)
    owner = owner_only(c.paginate('/v1/users', {'limit': 200}))
    email = owner['username']
    groups = c.paginate(f'/v1/apps/{APP}/betaGroups', {'limit': 200})
    matches = [g for g in groups if g['attributes']['name'] == GROUP]
    if len(matches) > 1:
        raise WorkflowError('Duplicate owner groups.')
    for group in groups:
        if group['attributes'].get('hasAccessToAllBuilds'):
            raise WorkflowError('An automatic group exists; inspect before uploading or distributing.')
    if not args.execute:
        return {'app': APP, 'group': GROUP, 'recipients': 1, 'internal': True, 'execute': False}
    if matches:
        group = matches[0]
    else:
        group = c.request('POST', '/v1/betaGroups', {'data': {
            'type': 'betaGroups', 'attributes': {'name': GROUP, 'isInternalGroup': True,
                'hasAccessToAllBuilds': False, 'publicLinkEnabled': False},
            'relationships': {'app': {'data': {'type': 'apps', 'id': APP}}}}})['data']
    gid = group['id']
    members = c.paginate(f'/v1/betaGroups/{gid}/betaTesters', {'limit': 200})
    check_group(group, members, email)
    if not members:
        testers = c.paginate('/v1/betaTesters', {'filter[email]': email, 'filter[apps]': APP, 'limit': 200})
        testers = [t for t in testers if t['attributes'].get('email', '').lower() == email.lower()]
        if len(testers) > 1:
            raise WorkflowError('Ambiguous tester identity.')
        if testers:
            c.request('POST', f'/v1/betaGroups/{gid}/relationships/betaTesters',
                {'data': [{'type': 'betaTesters', 'id': testers[0]['id']}]})
        else:
            c.request('POST', '/v1/betaTesters', {'data': {'type': 'betaTesters',
                'attributes': {'email': email, 'firstName': owner['firstName'], 'lastName': owner['lastName']},
                'relationships': {'betaGroups': {'data': [{'type': 'betaGroups', 'id': gid}]}}}})
    members = c.paginate(f'/v1/betaGroups/{gid}/betaTesters', {'limit': 200})
    group = c.request('GET', f'/v1/betaGroups/{gid}')['data']
    check_group(group, members, email)
    if len(members) != 1:
        raise WorkflowError('The owner was not confirmed as the sole tester.')
    receipt = {'app': APP, 'group': gid, 'groupName': GROUP, 'testerCount': 1,
               'internal': True, 'publicLinkEnabled': False}
    if args.command == 'setup':
        return receipt
    build = find_build(c, APP, args.version, args.build)
    if not build:
        raise WorkflowError('The exact valid build is not available.')
    bid = build['id']
    assigned = c.paginate('/v1/betaGroups', {'filter[builds]': bid, 'limit': 200})
    if any(g['id'] != gid for g in assigned):
        raise WorkflowError('Build has other group recipients; refusing to expand distribution.')
    detail = c.request('GET', f'/v1/builds/{bid}', params={'include': 'individualTesters'})['data']
    relation = detail['relationships']['individualTesters']
    individuals = relation.get('data', [])
    if relation.get('meta', {}).get('paging', {}).get('total', len(individuals)) != len(individuals):
        raise WorkflowError('Individual tester list is incomplete.')
    if any(t['id'] != members[0]['id'] for t in individuals):
        raise WorkflowError('Build has another individual tester.')
    if not assigned:
        c.request('POST', f'/v1/betaGroups/{gid}/relationships/builds', {'data': [{'type': 'builds', 'id': bid}]})
    assigned = c.paginate('/v1/betaGroups', {'filter[builds]': bid, 'limit': 200})
    if {g['id'] for g in assigned} != {gid}:
        raise WorkflowError('Build group assignment was not confirmed.')
    receipt.update(version=args.version, build=args.build, buildID=bid,
        betaDetail=c.request('GET', f'/v1/builds/{bid}/buildBetaDetail')['data']['attributes'])
    return receipt


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=['setup', 'distribute'])
    p.add_argument('--config', default='.asc-private/config.json')
    p.add_argument('--version', default='1.07')
    p.add_argument('--build', default='67')
    p.add_argument('--execute', action='store_true')
    p.add_argument('--output')
    args = p.parse_args()
    try:
        if args.command == 'distribute' and args.execute:
            from check_pixel_fonts import check
            typography_errors = check()
            if typography_errors:
                raise WorkflowError('Pixel typography check failed before distribution:\n' + '\n'.join(typography_errors))
        receipt = run(ASCClient(AuthConfig.load(args.config)), args)
        text = json.dumps(receipt, ensure_ascii=False, indent=2)
        if args.output:
            Path(args.output).write_text(text+'\n')
        print(text)
    except WorkflowError as e:
        p.exit(1, str(e)+'\n')

if __name__ == '__main__':
    main()
