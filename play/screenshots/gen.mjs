import { chromium } from 'playwright';
import { writeFileSync, mkdirSync } from 'fs';
import { page } from './ui.mjs';
import * as S from './screens.mjs';

const OUT = 'out';
mkdirSync(OUT, { recursive: true });

/* Each asset's wash is the hue the app itself gives that feature in
   lib/design/tokens.dart, deepened for a marketing background. */
export const SPECS = [
  { n: '01-home', grad: 'linear-gradient(165deg,#3B6DF0 0%,#1D4ED8 44%,#12296B 100%)',
    headline: 'Every past question.<br>One app.',
    sub: 'JAMB, WAEC, NECO, NABTEB, GCE and Post-UTME — practice, notes, games and your real rank.',
    inner: S.home() },

  { n: '02-practice', grad: 'linear-gradient(165deg,#2F62E8 0%,#1B47C4 45%,#0F2C86 100%)',
    headline: 'Train the way<br>you will be tested.',
    sub: 'By year, by topic or a random mix. Open practice, or a clock that runs exactly like the hall.',
    inner: S.practice() },

  { n: '03-sitting', grad: 'linear-gradient(165deg,#4C3BD6 0%,#3728B8 45%,#1E167A 100%)',
    headline: 'A real CBT,<br>down to the clock.',
    sub: 'No answers until you submit. Flag a question, jump the grid, and sit a full 180-question UTME mock scored over 400.',
    inner: S.sitting() },

  { n: '04-result', grad: 'linear-gradient(165deg,#1C9A62 0%,#107A46 45%,#064F2B 100%)',
    headline: 'Your score,<br>the second you submit.',
    sub: 'Broken down subject by subject, weakest first — then walk back through every question you missed.',
    inner: S.result() },

  { n: '05-analysis', grad: 'linear-gradient(165deg,#4A3BD2 0%,#3728B8 45%,#211A72 100%)',
    headline: 'See where your<br>marks are going.',
    sub: 'Every paper plotted over time, and the exact topics costing you the most — sorted weakest first.',
    inner: S.analysis() },

  { n: '06-classroom', grad: 'linear-gradient(165deg,#8A3BD2 0%,#6B28B8 45%,#3F1570 100%)',
    headline: 'Notes, videos<br>and files to keep.',
    sub: 'Written lessons, video explanations and downloadable material from your tutors — room by room, subject by subject.',
    inner: S.classroom() },

  { n: '07-vault', grad: 'linear-gradient(165deg,#1D8E91 0%,#186C6F 45%,#0B4446 100%)',
    headline: 'Download once.<br>Study with no data.',
    sub: 'On a bus, in a village, with no signal at all. Your results are sent home the next time you connect.',
    inner: S.vault() },

  { n: '08-climb', grad: 'linear-gradient(165deg,#C98F1B 0%,#A4721A 45%,#5E4007 100%)',
    headline: 'Fifteen rungs.<br>Three lifelines.',
    sub: 'The Climb, Blitz 60, Survival and Daily Ten — real questions from the same bank, with a clock on.',
    inner: S.climb() },
];

const only = process.argv[2];
const run = only ? SPECS.filter((s) => s.n.includes(only)) : SPECS;

const browser = await chromium.launch({
  executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
});
const ctx = await browser.newContext({
  viewport: { width: 720, height: 1280 },
  deviceScaleFactor: 2,
});
const pg = await ctx.newPage();

for (const s of run) {
  writeFileSync(`${s.n}.html`, page(s));
  await pg.goto(`file://${process.cwd()}/${s.n}.html`);
  await pg.waitForTimeout(300);
  await pg.screenshot({ path: `${OUT}/${s.n}.png` });
  console.log('rendered', s.n);
}

await browser.close();
