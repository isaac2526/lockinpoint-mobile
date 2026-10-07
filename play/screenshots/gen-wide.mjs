import { chromium } from 'playwright';
import { writeFileSync, mkdirSync } from 'fs';
import { widePage, featurePage } from './frames.mjs';
import { WIDE } from './wide.mjs';

/* Every wide family is the same 1280x720 layout captured at a different
   scale, which is how one set of markup satisfies four different Play
   minimums without a single reflow. All are exactly 16:9. */
const FAMILIES = [
  { dir: 'tablet-7',  kind: 'tablet',  scale: 2,    px: '2560x1440' },
  { dir: 'tablet-10', kind: 'tablet',  scale: 2.5,  px: '3200x1800' },
  { dir: 'desktop',   kind: 'desktop', scale: 2.25, px: '2880x1620' },
  { dir: 'xr',        kind: 'xr',      scale: 2,    px: '2560x1440' },
];

mkdirSync('out', { recursive: true });

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
});

/* ---- feature graphic ---------------------------------------------------- */
{
  const ctx = await browser.newContext({ viewport: { width: 1024, height: 500 }, deviceScaleFactor: 1 });
  const pg = await ctx.newPage();
  writeFileSync('_feature.html', featurePage());
  await pg.goto(`file://${process.cwd()}/_feature.html`);
  await pg.waitForTimeout(350);
  await pg.screenshot({ path: 'out/feature-graphic-1024x500.png' });
  await ctx.close();
  console.log('rendered feature-graphic-1024x500');
}

/* ---- the four wide families -------------------------------------------- */
for (const f of FAMILIES) {
  mkdirSync(`out/${f.dir}`, { recursive: true });
  const ctx = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: f.scale,
  });
  const pg = await ctx.newPage();
  for (const [i, s] of WIDE.entries()) {
    const file = `${String(i + 1).padStart(2, '0')}-${s.n}`;
    writeFileSync(`_w.html`, widePage({ kind: f.kind, headline: s.headline, sub: s.sub, grad: s.grad, inner: s.inner() }));
    await pg.goto(`file://${process.cwd()}/_w.html`);
    await pg.waitForTimeout(260);
    await pg.screenshot({ path: `out/${f.dir}/${file}.png` });
  }
  await ctx.close();
  console.log(`rendered ${f.dir} (${WIDE.length} @ ${f.px})`);
}

await browser.close();
