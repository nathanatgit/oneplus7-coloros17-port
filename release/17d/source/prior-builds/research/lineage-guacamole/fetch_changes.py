import base64, concurrent.futures, json, pathlib, urllib.request
root = pathlib.Path(__file__).resolve().parent
rows = json.loads((root/'changelog-rows.json').read_text())
out = root/'reviews'; out.mkdir(exist_ok=True)
def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'OnePlus7Port-source-audit'}), timeout=45) as r:
        return r.read()
def fetch(row):
    try:
        p = out/(row['id']+'.json')
        if not p.exists():
            data=get('https://review.lineageos.org/changes/'+row['id']+'/detail?o=CURRENT_REVISION&o=CURRENT_COMMIT&o=CURRENT_FILES')
            p.write_text(data.decode().removeprefix(")]}'\n"), encoding='utf-8')
        patch=out/(row['id']+'.patch')
        if not patch.exists():
            patch.write_bytes(base64.b64decode(get('https://review.lineageos.org/changes/'+row['id']+'/revisions/current/patch?parent=1')))
        return row['id'], 'saved'
    except Exception as e: return row['id'], str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    results=list(pool.map(fetch,rows))
(root/'fetch-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('Saved:',sum(v=='saved' for _,v in results),'/',len(rows))
for k,v in results:
    if v!='saved': print(k,v)
