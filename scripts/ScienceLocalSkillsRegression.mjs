// 对已启动的隔离 Science 实例执行本地技能验收，不使用任何 Claude 账号。
import assert from 'node:assert/strict';

const baseURL = process.argv[2];
if (!baseURL || !/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(baseURL)) {
  throw new Error('Usage: node scripts/ScienceLocalSkillsRegression.mjs http://localhost:<port>');
}
const home = await fetch(baseURL);
assert.equal(home.status, 200);
const csrf = home.headers.getSetCookie().map(value => value.split(';')[0])
  .find(value => value.startsWith('operon_csrf='))?.slice('operon_csrf='.length);
assert.ok(csrf, 'Local CSRF cookie is missing');

async function request(path, method = 'GET', body) {
  const headers = {'x-operon-csrf': csrf, Origin: baseURL};
  if (body && !(body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(body);
  }
  const response = await fetch(baseURL + path, {method, headers, body});
  const result = await response.json();
  assert.ok(response.ok, `${method} ${path}: ${response.status} ${JSON.stringify(result)}`);
  return result;
}

const prefix = `aiusage-local-check-${Date.now()}`;
const names = [prefix + '-import', prefix + '-create', prefix + '-copy'];
const content = name => `---\nname: ${name}\ndescription: Local regression marker\n---\n\nReturn LOCAL_SKILL_OK.\n`;
try {
  const auth = await request('/api/auth/status');
  assert.equal(auth.provider, 'aiusage_local');
  assert.equal(auth.authenticated, true);
  assert.equal(auth.reauth_required, false);
  const catalog = await request('/api/skills/catalog');
  assert.equal(catalog.degraded, false, 'Cloud failure must not degrade the local catalog');
  assert.ok(catalog.skills.length > 0, 'Bundled skills must remain available');

  const upload = new FormData();
  upload.append('file', new Blob([content(names[0])]), names[0] + '.md');
  const imported = await request('/api/skills/import', 'POST', upload);
  assert.equal(imported.name, names[0]);
  await request(`/api/skills/${names[1]}/edit`, 'POST', {
    path: 'SKILL.md', old_string: '', new_string: content(names[1]),
  });
  await request(`/api/skills/${names[0]}/edit`, 'POST', {
    path: 'SKILL.md', old_string: 'LOCAL_SKILL_OK', new_string: 'LOCAL_SKILL_EDIT_OK',
  });
  await request(`/api/skills/${names[2]}/duplicate`, 'POST', {sourceName: names[0]});
  const drafts = await request('/api/skills/drafts');
  for (const name of names) assert.ok(drafts.drafts.includes(name), `${name} is missing`);
  const files = await request(`/api/skills/catalog/${names[0]}/files`);
  assert.ok(JSON.stringify(files).includes('SKILL.md'));
  const edited = await request(`/api/skills/catalog/${names[0]}/content?path=SKILL.md`);
  assert.ok(JSON.stringify(edited).includes('LOCAL_SKILL_EDIT_OK'));
  await request('/api/agents/OPERON/skills', 'POST', {skill_name: names[0]});
  console.log(`LOCAL_SKILLS_OK: bundled=${catalog.skills.length}, import/create/edit/duplicate/read/attach passed; no Claude login`);
} finally {
  for (const name of names) {
    await request(`/api/agents/OPERON/skills/${name}`, 'DELETE').catch(() => {});
    await request(`/api/skills/${name}`, 'DELETE').catch(() => {});
  }
}
