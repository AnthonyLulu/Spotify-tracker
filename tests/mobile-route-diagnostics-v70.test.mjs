import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const yaml=fs.readFileSync(new URL('../.github/workflows/court-boss-mobile-ux-rc.yml',import.meta.url),'utf8');

test('mobile diagnostic instruments exactly one navigation per route',()=>{
 const block=yaml.slice(yaml.indexOf('for(const route of routes){'),yaml.indexOf('await page.locator(\'main.page\')',yaml.indexOf('for(const route of routes){')));
 assert.equal((block.match(/window\.nav\(r\)/g)||[]).length,1);
 assert.match(block,/const navPromise=Promise\.resolve\(window\.nav\(r\)\)/);
 assert.match(block,/navPromise\.then/);
 assert.match(block,/await Promise\.race\(\[\s*navPromise/);
});

test('a timed out route reports unresolved navigation and active API requests, not a false green',()=>{
 assert.match(yaml,/MOBILE_ROUTE_FAIL/);
 assert.match(yaml,/pendingApi:/);
 assert.match(yaml,/screenTitle/);
 assert.match(yaml,/throw err/);
 assert.match(yaml,/MOBILE_ROUTE_NAV_DONE/);
});
