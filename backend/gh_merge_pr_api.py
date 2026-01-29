#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.error

OWNER = "Khamvang"
REPO = "approval-system"
PR_NUMBER = 1
API_BASE = f"https://api.github.com/repos/{OWNER}/{REPO}"

def request_json(path, method='GET', body=None, extra_headers=None):
    url = API_BASE + path
    data = None
    headers = {'User-Agent': 'gh-merge-script'}
    if extra_headers:
        headers.update(extra_headers)
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        raise SystemExit('GITHUB_TOKEN not set in environment')
    headers['Authorization'] = f'token {token}'
    if body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            text = resp.read().decode('utf-8')
            if text:
                return json.loads(text)
            return None
    except urllib.error.HTTPError as e:
        try:
            err_text = e.read().decode('utf-8')
            err_json = json.loads(err_text)
            print(f'HTTP {e.code} {e.reason}:', err_json, file=sys.stderr)
        except Exception:
            print(f'HTTP {e.code} {e.reason}', file=sys.stderr)
        return None


def main():
    pr = request_json(f"/pulls/{PR_NUMBER}")
    if pr is None:
        print('Failed to fetch PR info; aborting')
        return 2
    if pr.get('merged'):
        print('PR is already merged.')
        return 0
    draft = pr.get('draft', False)
    state = pr.get('state')
    print('PR state:', state, 'draft:', draft)

    if draft:
        print('Attempting to mark PR ready for review...')
        ready = request_json(f"/pulls/{PR_NUMBER}/ready_for_review", method='POST')
        if ready is None:
            print('ready_for_review endpoint returned error; trying PATCH')
            patched = request_json(f"/pulls/{PR_NUMBER}", method='PATCH', body={'draft': False})
            if patched is None:
                print('Failed to unset draft flag via PATCH; aborting')
                return 3
        else:
            print('ready_for_review called successfully')

        # re-fetch
        pr = request_json(f"/pulls/{PR_NUMBER}")
        if pr is None:
            print('Failed to re-fetch PR info; aborting')
            return 4
        draft = pr.get('draft', False)
        print('After conversion attempt, draft:', draft)
        if draft:
            print('PR still draft; cannot merge via API. Aborting.')
            return 5

    print('Attempting to merge PR...')
    merge_body = {
        'commit_title': f"Merge pull request #{PR_NUMBER} from {OWNER}/feature/split-first-last-name",
        'merge_method': 'merge'
    }
    merged = request_json(f"/pulls/{PR_NUMBER}/merge", method='PUT', body=merge_body)
    if merged is None:
        print('Merge request failed or returned non-JSON response; check stderr')
        return 6
    if merged.get('merged'):
        print('PR merged successfully.')
        return 0
    else:
        print('Merge attempt did not complete:', merged)
        return 7

if __name__ == '__main__':
    sys.exit(main())
