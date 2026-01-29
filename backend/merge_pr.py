import requests, json

# NOTE: Do NOT store Personal Access Tokens in source. Read from environment.
import os
TOKEN = os.environ.get('GITHUB_TOKEN') or os.environ.get('GITHUB_PAT')
if not TOKEN:
    raise RuntimeError('GITHUB_TOKEN or GITHUB_PAT environment variable is required')
headers = {'Authorization': f'token {TOKEN}', 'User-Agent': 'merge-script'}
owner = 'Khamvang'
repo = 'approval-system'
pr = 1

patch_url = f'https://api.github.com/repos/{owner}/{repo}/pulls/{pr}'
print('POST ready_for_review', patch_url + '/ready_for_review')
# Use dedicated endpoint to mark draft PR as ready
r_ready = requests.post(patch_url + '/ready_for_review', headers=headers)
print(r_ready.status_code)
try:
    print(json.dumps(r_ready.json(), indent=2))
except Exception:
    print(r_ready.text)

if r_ready.status_code in (200, 201):
    merge_url = f'https://api.github.com/repos/{owner}/{repo}/pulls/{pr}/merge'
    print('\nPUT', merge_url)
    r2 = requests.put(merge_url, json={'commit_title': 'Merge PR #1: Split full name into first/last, add nickname and UI fixes', 'merge_method': 'merge'}, headers=headers)
    print(r2.status_code)
    try:
        print(json.dumps(r2.json(), indent=2))
    except Exception:
        print(r2.text)
else:
    print('Mark ready failed; not attempting merge')
