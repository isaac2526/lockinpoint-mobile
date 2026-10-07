import { C, H, icon } from './ui.mjs';

/* =============================================================================
   LANDSCAPE · the layout LockInPoint shows on a wide screen: a persistent
   rail instead of a bottom bar, and two working columns instead of one.
   Authored at 872x572 CSS px, which is the screen inside every wide frame
   (tablet, desktop, XR), so one set of screens feeds all three families.
   ========================================================================== */

export const WIDE_W = 872;
export const WIDE_H = 572;

export const wcss = `<style>
  .ws{display:flex;height:${WIDE_H}px;background:${C.bg};font-family:IN,sans-serif;color:${C.t1}}
  .rail{width:196px;flex:none;background:#fff;border-right:1px solid ${C.border};padding:14px 11px;
        display:flex;flex-direction:column;gap:3px}
  .rail .brand{display:flex;align-items:center;gap:8px;padding:3px 5px 13px}
  .rail .wm{font-family:SG;font-weight:700;font-size:15px;letter-spacing:-.4px}
  .ri{display:flex;align-items:center;gap:9px;padding:8px 10px;border-radius:11px;
      font-size:12px;font-weight:600;color:${C.t2}}
  .ri.on{background:${H.blue.tint};color:${C.brand};font-weight:700}
  .rsep{height:1px;background:${C.border};margin:9px 5px}
  .rlbl{font-size:8.5px;font-weight:700;letter-spacing:1.2px;color:${C.t3};padding:4px 10px 3px}
  .wmain{flex:1;padding:16px 18px;overflow:hidden;position:relative}
  .wtop{display:flex;align-items:center;justify-content:space-between;margin-bottom:13px}
  .wtitle{font-family:SG;font-weight:700;font-size:21px;letter-spacing:-.6px}
  .wsub{font-size:11.5px;color:${C.t3};font-weight:500;margin-top:2px}
  .cols{display:flex;gap:14px;align-items:flex-start}
  .wcard{background:#fff;border:1px solid ${C.border};border-radius:16px}
  .wdeep{background:#F0F2F7;border:1px solid ${C.border};border-radius:14px}
  .wlbl{font-size:9px;font-weight:700;letter-spacing:1.2px;color:${C.t3};
        text-transform:uppercase;margin:0 0 7px}
  .wchip{display:inline-flex;align-items:center;gap:5px;height:27px;padding:0 11px;border-radius:999px;
         font-size:11px;font-weight:600;border:1px solid ${C.border};background:#fff;color:${C.t2}}
  .wchip.on{background:${C.brand};border-color:${C.brand};color:#fff}
  .wchip.gold{background:#FBF1DF;border-color:#EBD9A8;color:${C.accent}}
  .wchips{display:flex;flex-wrap:wrap;gap:6px}
  .wtile{border-radius:15px;padding:11px 11px 12px}
  .wtile .ti{width:30px;height:30px;border-radius:10px;background:rgba(255,255,255,.75);
             display:flex;align-items:center;justify-content:center}
  .wtile h3{font-family:SG;font-weight:700;font-size:12px;margin-top:8px;letter-spacing:-.2px}
  .wtile p{font-size:9.5px;line-height:1.3;margin-top:2px;font-weight:500;opacity:.8}
  .wcc{display:flex;align-items:center;gap:10px;background:#fff;border:1px solid ${C.border};
       border-radius:14px;padding:10px 11px;margin-bottom:7px}
  .wcc.on{border-color:${C.brand};box-shadow:0 0 0 1.5px ${C.brand}}
  .wcc .ci{width:31px;height:31px;border-radius:10px;flex:none;display:flex;align-items:center;
           justify-content:center}
  .wcc h4{font-family:SG;font-weight:700;font-size:12px;letter-spacing:-.2px}
  .wcc p{font-size:9.5px;color:${C.t3};margin-top:1px;font-weight:500;line-height:1.3}
  .wbtn{height:40px;border-radius:13px;background:${C.brand};color:#fff;display:flex;
        align-items:center;justify-content:center;gap:7px;font-weight:700;font-size:13px;
        font-family:SG;letter-spacing:-.2px;box-shadow:0 6px 14px rgba(29,78,216,.24)}
  .wbtn.gold{background:${C.gold};color:#241A00;box-shadow:0 6px 14px rgba(217,162,19,.28)}
  .wbtn.ghost{background:#fff;border:1px solid ${C.border};color:${C.t1};box-shadow:none}
  .wbar{height:6px;border-radius:999px;background:#EDF0F6;overflow:hidden}
  .wbar i{display:block;height:100%;border-radius:999px}
  .wstat{flex:1;border-radius:13px;background:#F0F2F7;border:1px solid ${C.border};
         padding:9px 7px;text-align:center}
  .wstat b{font-family:JB;font-weight:700;font-size:16px;display:block}
  .wstat span{font-size:8.5px;color:${C.t3};font-weight:600}
  .wopt{display:flex;align-items:center;gap:9px;background:#fff;border:1px solid ${C.border};
        border-radius:13px;padding:11px;margin-bottom:7px;font-size:12px}
  .wol{width:22px;height:22px;border-radius:50%;flex:none;display:flex;align-items:center;
       justify-content:center;font-weight:700;font-size:11px;background:#EEF1F7;color:${C.t2}}
  .mono{font-family:JB;font-weight:700;font-variant-numeric:tabular-nums}
  .wrow{display:flex;align-items:center}
</style>`;

const wordmark = `<span class="wm">LockIn<span style="color:${C.brand}">Point</span></span>`;
const logo = `<div style="width:24px;height:24px;border-radius:7px;flex:none;
  background:linear-gradient(145deg,#4A79F2,#0F2C86);display:flex;align-items:center;
  justify-content:center;color:#F7D269;font-family:SG;font-weight:700;font-size:11px">LP</div>`;

/* The rail. Primary destinations from app/shell.dart, then the drawer's
   'Learning' group, which is what a wide screen has room to keep open. */
const rail = (active) => {
  const main = [['home', 'Home'], ['rocket', 'Practice & CBT'], ['leaderboard', 'Leaderboard'], ['person', 'Profile']];
  const more = [['book', 'Classroom'], ['insights', 'Performance analysis'], ['gamepad', 'Games arena'],
                ['bolt', 'Offline vault'], ['bookmark', 'Saved questions'], ['robot', 'Ask Lumi']];
  const row = ([ic, lb]) => `<div class="ri ${lb === active ? 'on' : ''}">
      ${icon(ic, 16, lb === active ? C.brand : C.t3)}${lb}</div>`;
  return `<aside class="rail">
    <div class="brand">${logo}${wordmark}</div>
    ${main.map(row).join('')}
    <div class="rsep"></div><div class="rlbl">LEARNING</div>
    ${more.map(row).join('')}
  </aside>`;
};

const wtile = (h, name, title, sub) => `
  <div class="wtile" style="background:${h.tint}">
    <div class="ti">${icon(name, 17, h.ink)}</div>
    <h3 style="color:${h.ink}">${title}</h3><p style="color:${h.ink}">${sub}</p></div>`;

const wcc = (h, ic, title, sub, on = false) => `
  <div class="wcc ${on ? 'on' : ''}">
    <div class="ci" style="background:${h.tint}">${icon(ic, 16, h.ink)}</div>
    <div style="flex:1"><h4 style="${on ? `color:${C.brand}` : ''}">${title}</h4><p>${sub}</p></div></div>`;

const wsbar = (name, got, tot, pct, col) => `
  <div class="wrow" style="gap:8px;font-size:11px;font-weight:600;margin-bottom:4px">
    <span style="flex:1">${name}</span>
    <span class="mono" style="font-size:10px;color:${C.t3}">${got}/${tot}</span>
    <span style="width:30px;text-align:right;color:${col}">${pct}%</span></div>
  <div class="wbar" style="margin-bottom:10px"><i style="width:${pct}%;background:${col}"></i></div>`;

/* ------------------------------------------------------------ 1 · HOME -- */
export const wHome = () => `${wcss}<div class="ws">${rail('Home')}
  <main class="wmain">
    <div class="wtop">
      <div><div class="wtitle">Welcome back, Isaac</div>
        <div class="wsub">What are you doing today?</div></div>
      <div class="wrow" style="gap:9px">
        <div style="display:flex;align-items:center;gap:4px;background:#FBF1DF;border-radius:11px;
             padding:6px 11px">${icon('flame', 13, H.amber.ink)}
          <b class="mono" style="font-size:13px;color:${H.amber.ink}">12</b>
          <span style="font-size:9px;font-weight:600;color:${H.amber.ink}">day streak</span></div>
        <div style="width:30px;height:30px;border-radius:50%;background:linear-gradient(145deg,#4A79F2,#0F2C86);
             color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;
             font-size:11px">IA</div>
      </div>
    </div>

    <div class="cols" style="gap:11px;margin-bottom:12px">
      <div class="wcard" style="flex:2;padding:10px 12px;display:flex;align-items:center;gap:10px">
        <div style="width:34px;height:34px;border-radius:11px;background:${H.blue.tint};flex:none;
             display:flex;align-items:center;justify-content:center">${icon('rocket', 17, H.blue.ink)}</div>
        <div style="flex:1">
          <div style="font-family:SG;font-weight:700;font-size:12px">Continue where you stopped</div>
          <div style="font-size:9.5px;color:${C.t3};font-weight:500">JAMB · Mathematics · Random mix</div>
          <div class="wbar" style="margin-top:6px"><i style="width:45%;background:${C.brand}"></i></div>
        </div>${icon('chev', 15, C.t3)}</div>
      <div class="wstat"><b>40.1k</b><span>questions live</span></div>
      <div class="wstat"><b>37</b><span>sittings done</span></div>
      <div class="wstat"><b>284</b><span>notes &amp; videos</span></div>
    </div>

    <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:9px">
      ${wtile(H.blue, 'rocket', 'Practice &amp; CBT', 'Real past questions, timed or open')}
      ${wtile(H.violet, 'book', 'Classroom', 'Notes, materials and video lessons')}
      ${wtile(H.slate, 'search', 'Question search', 'Find any question, fast')}
      ${wtile(H.green, 'receipt', 'Result history', 'Every paper you have sat')}
      ${wtile(H.indigo, 'insights', 'Performance analysis', 'Where your marks are going')}
      ${wtile(H.purple, 'gamepad', 'Games arena', 'Blitz, Survival, The Climb')}
      ${wtile(H.amber, 'trophy', 'The Climb', 'Fifteen rungs, three lifelines')}
      ${wtile(H.pink, 'leaderboard', 'Leaderboard', 'Your rank, nationally and locally')}
      ${wtile(H.lime, 'bookmark', 'Saved questions', 'Everything you kept')}
      ${wtile(H.teal, 'bolt', 'Offline vault', 'Downloaded questions, no signal needed')}
      ${wtile(H.orange, 'school', 'Career &amp; institutions', 'Courses, schools and cut-offs')}
      ${wtile(H.rose, 'robot', 'Ask Lumi', 'Your AI tutor, any question')}
    </div>
  </main></div>`;

/* -------------------------------------------------------- 2 · PRACTICE -- */
export const wPractice = () => `${wcss}<div class="ws">${rail('Practice & CBT')}
  <main class="wmain">
    <div class="wtop"><div><div class="wtitle">Mathematics</div>
      <div class="wsub">Step 3 of 3</div></div>
      <span class="wchip gold">JAMB</span></div>
    <div class="cols">
      <div style="flex:1.15">
        ${wcc(H.blue, 'shuffle', 'Random mix', 'A spread across every year', true)}
        ${wcc(H.blue, 'cal', 'By year', 'One real past paper year')}
        ${wcc(H.blue, 'layers', 'By topic', 'Drill one topic until it yields')}
        ${wcc(H.slate, 'school', 'Tutorial questions', 'Teaching material, no exam year')}
        <div class="wlbl" style="margin-top:13px">Keep Mathematics on your phone</div>
        <div class="wrow" style="gap:8px;border:1px solid ${C.border};background:#fff;
             border-radius:13px;padding:9px 11px">
          <div style="width:28px;height:28px;border-radius:9px;background:${H.teal.tint};flex:none;
               display:flex;align-items:center;justify-content:center">${icon('down', 14, H.teal.ink)}</div>
          <div style="flex:1;font-size:11.5px;font-weight:700;font-family:SG">Download for offline</div>
          <span class="wchip" style="height:23px;font-size:9.5px;padding:0 9px">420 questions</span>
        </div>
      </div>
      <div style="flex:1">
        <div class="wlbl">How many questions</div>
        <div class="wchips"><span class="wchip">10</span><span class="wchip">20</span>
          <span class="wchip on">40</span><span class="wchip">60</span>
          <span class="wchip">100</span><span class="wchip">Other</span></div>
        <div class="wlbl" style="margin-top:14px">How do you want to sit it</div>
        ${wcc(H.slate, 'play', 'Practice', 'No clock. See the answer and the why after each question')}
        ${wcc(H.amber, 'clock', 'CBT', 'A clock, no answers until you submit, exactly like the hall', true)}
        <div class="wlbl" style="margin-top:12px">How long</div>
        <div class="wchips"><span class="wchip">10 min</span><span class="wchip">20 min</span>
          <span class="wchip on">30 min</span><span class="wchip">45 min</span>
          <span class="wchip">60 min</span><span class="wchip">120 min</span></div>
        <div class="wdeep" style="margin-top:14px;padding:10px 12px;font-size:11px;font-weight:600;
             color:${C.t2}">JAMB · Mathematics · Random mix · CBT</div>
        <div class="wbtn gold" style="margin-top:10px">${icon('clock', 15, '#241A00')} Start the clock</div>
      </div>
    </div>
  </main></div>`;

/* --------------------------------------------------------- 3 · SITTING -- */
export const wSitting = () => `${wcss}<div class="ws">
  <main class="wmain" style="padding:0">
    <div class="wrow" style="gap:11px;padding:13px 18px 0">
      ${icon('cross', 17, C.t2)}
      <div style="flex:1"><div style="font-family:SG;font-weight:700;font-size:13px">JAMB mock · 4 subjects</div>
        <div style="font-size:10px;color:${C.t3};font-weight:500">Question 47 of 180 · 44 answered</div></div>
      <div class="wrow" style="gap:5px;background:#FBF1DF;border:1px solid #EBD9A8;border-radius:999px;
           padding:5px 12px">${icon('clock', 13, H.amber.ink)}
        <b class="mono" style="font-size:13px;color:${H.amber.ink}">54:12</b></div>
      ${icon('grid4', 17, C.t2)}
      <span style="font-family:SG;font-weight:700;font-size:12.5px;color:${C.brand}">Submit</span>
    </div>
    <div class="wrow" style="gap:6px;padding:11px 18px 0">
      <span class="wchip">Use of English</span><span class="wchip on">Mathematics</span>
      <span class="wchip">Physics</span><span class="wchip">Chemistry</span></div>
    <div style="height:3px;background:#E7EBF3;margin-top:11px">
      <div style="width:26%;height:100%;background:${C.brand}"></div></div>

    <div class="cols" style="padding:14px 18px 0;gap:16px">
      <div style="flex:1.05">
        <div class="wrow" style="gap:6px;margin-bottom:9px">
          <span class="wchip" style="height:24px;font-size:10px">2021</span>
          <span class="wchip" style="height:24px;font-size:10px">Algebra</span>
          <span style="flex:1"></span>
          <span class="wchip gold" style="height:24px;font-size:10px">Flagged</span></div>
        <div class="wcard" style="padding:14px;box-shadow:0 4px 12px rgba(11,16,32,.05)">
          <div style="font-size:13.5px;line-height:1.55;font-weight:500">
            A trader bought 120 oranges at ₦25 each. She sold two-thirds of them at ₦40 each and the
            remainder at ₦30 each. Find her percentage profit, correct to one decimal place.</div>
          <div class="wrow" style="gap:14px;margin-top:13px;padding-top:11px;
               border-top:1px solid ${C.border}">
            ${icon('bookmark', 15, C.t3)}${icon('speaker', 15, C.t3)}${icon('robot', 15, C.t3)}</div>
        </div>
        <div class="wdeep" style="margin-top:11px;padding:10px 12px;font-size:10.5px;font-weight:600;
             color:${C.t3}">No answers until you submit — exactly like the hall.</div>
      </div>
      <div style="flex:1">
        <div class="wlbl">Choose one</div>
        <div class="wopt"><div class="wol">A</div><div>21.3%</div></div>
        <div class="wopt" style="border-color:${C.brand};box-shadow:0 0 0 1.5px ${C.brand}">
          <div class="wol" style="background:${C.brand};color:#fff">B</div><div>46.7%</div></div>
        <div class="wopt"><div class="wol">C</div><div>33.3%</div></div>
        <div class="wopt"><div class="wol">D</div><div>52.0%</div></div>
        <div class="wrow" style="gap:9px;margin-top:13px">
          <div style="width:40px;height:40px;border-radius:13px;background:#EEF1F7;display:flex;
               align-items:center;justify-content:center;transform:rotate(180deg)">
            ${icon('chev', 16, C.t2)}</div>
          <div class="wbtn" style="flex:1">Next question</div>
          <span class="mono" style="font-size:11px;color:${C.t3}">47/180</span></div>
      </div>
    </div>
  </main></div>`;

/* ---------------------------------------------------------- 4 · RESULT -- */
export const wResult = () => `${wcss}<div class="ws">${rail('Home')}
  <main class="wmain">
    <div class="cols" style="gap:20px;align-items:center;height:100%">
      <div style="flex:1;text-align:center">
        <div style="width:142px;height:142px;border-radius:50%;margin:0 auto;
             border:3px solid ${C.success};display:flex;align-items:center;justify-content:center">
          <b class="mono" style="font-size:46px;color:${C.success};line-height:1">265</b></div>
        <div style="font-size:11.5px;color:${C.t3};font-weight:600;margin-top:9px">out of 400</div>
        <div style="font-family:SG;font-weight:700;font-size:22px;margin-top:14px;letter-spacing:-.5px">
          Sharp. Keep this pace.</div>
        <div style="font-size:12px;color:${C.t3};font-weight:500;margin-top:6px">
          119 of 180 correct · JAMB mock</div>
      </div>
      <div style="flex:1.1">
        <div class="wlbl">Subject by subject, weakest first</div>
        <div class="wcard" style="padding:14px 15px 5px">
          ${wsbar('Chemistry', 22, 40, 55, H.amber.ink)}
          ${wsbar('Physics', 27, 40, 68, H.amber.ink)}
          ${wsbar('Mathematics', 28, 40, 70, C.success)}
          ${wsbar('Use of English', 42, 60, 70, C.success)}
        </div>
        <div class="wbtn gold" style="margin-top:13px">
          ${icon('check', 15, '#241A00')} See what you missed</div>
        <div class="wbtn ghost" style="margin-top:8px">
          ${icon('home', 14, C.t1)} Back to the dashboard</div>
      </div>
    </div>
  </main></div>`;

/* -------------------------------------------------------- 5 · ANALYSIS -- */
const wspark = () => {
  const pts = [38, 46, 42, 55, 61, 58, 70, 74, 81];
  const W = 352, Hh = 150;
  const xy = pts.map((v, i) => [26 + (i * (W - 38)) / (pts.length - 1), Hh - (v / 100) * (Hh - 14) - 6]);
  const line = xy.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const grid = [0, 25, 50, 75, 100].map((g) => {
    const y = Hh - (g / 100) * (Hh - 14) - 6;
    return `<line x1="24" y1="${y.toFixed(1)}" x2="${W}" y2="${y.toFixed(1)}" stroke="#E7EBF3"/>
      <text x="0" y="${(y + 3.5).toFixed(1)}" font-size="9" fill="${C.t3}" font-family="IN">${g}</text>`;
  }).join('');
  return `<svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">${grid}
    <path d="${line} L${xy.at(-1)[0].toFixed(1)} ${Hh} L${xy[0][0].toFixed(1)} ${Hh} Z"
          fill="${H.indigo.ink}" opacity=".10"/>
    <path d="${line}" fill="none" stroke="${H.indigo.ink}" stroke-width="2.6"
          stroke-linecap="round" stroke-linejoin="round"/>
    ${xy.map((p) => `<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="3.4" fill="#fff"
          stroke="${H.indigo.ink}" stroke-width="2.2"/>`).join('')}</svg>`;
};

const wtopic = (name, pct, seen, tot, subj, col) => `
  <div style="margin-bottom:9px">
    <div class="wrow" style="justify-content:space-between;font-size:11px;font-weight:600">
      <span>${name}</span><b style="color:${col}">${pct}%</b></div>
    <div class="wbar" style="margin-top:4px"><i style="width:${pct}%;background:${col}"></i></div>
    <div style="font-size:9px;color:${C.t3};margin-top:3px;font-weight:500">${seen} of ${tot} · ${subj}</div>
  </div>`;

export const wAnalysis = () => `${wcss}<div class="ws">${rail('Performance analysis')}
  <main class="wmain">
    <div class="wtop"><div><div class="wtitle">Performance analysis</div>
      <div class="wsub">9 finished sittings</div></div></div>
    <div style="display:flex;gap:9px;background:${H.indigo.tint};border-radius:13px;padding:10px 12px;
         margin-bottom:12px">${icon('bulb', 16, H.indigo.ink)}
      <div style="font-size:10.5px;line-height:1.4;font-weight:500;color:${H.indigo.ink}">
        Your Chemistry has climbed 14 points in three papers. Quadratic Equations is now the one
        costing you most.</div></div>
    <div class="cols">
      <div style="flex:1">
        <div class="wlbl">Score over time</div>
        <div class="wcard" style="padding:11px 11px 7px">${wspark()}
          <div style="font-size:8.5px;color:${C.t3};line-height:1.4;margin-top:5px;font-weight:500">
            9 papers, oldest on the left. The scale runs 0 to 100 — a percentage cannot go below
            zero, so the axis does not either.</div></div>
      </div>
      <div style="flex:1">
        <div class="wlbl">Topic by topic</div>
        <div style="background:${H.indigo.tint};border-radius:14px;padding:11px 12px 3px">
          <div style="font-family:SG;font-weight:700;font-size:11.5px;color:${H.indigo.ink};
               margin-bottom:9px">Revise these first</div>
          ${wtopic('Quadratic Equations', 22, 4, 18, 'Mathematics', C.danger)}
          ${wtopic('Mole Concept', 35, 7, 20, 'Chemistry', C.danger)}
          ${wtopic('Vectors', 48, 11, 23, 'Physics', H.amber.ink)}</div>
        <div class="wcard" style="margin-top:9px;padding:11px 12px 3px">
          <div style="font-family:SG;font-weight:700;font-size:11.5px;margin-bottom:9px">Solid ground</div>
          ${wtopic('Comprehension', 88, 22, 25, 'Use of English', C.success)}</div>
      </div>
    </div>
  </main></div>`;

/* ------------------------------------------------------- 6 · CLASSROOM -- */
const wrow = (h, ic, title, on = false) => `
  <div class="wrow" style="gap:9px;background:${on ? H.violet.tint : '#fff'};
       border:1px solid ${on ? 'transparent' : C.border};border-radius:12px;padding:9px 10px;
       margin-bottom:6px">
    <div style="width:27px;height:27px;border-radius:9px;background:${on ? '#fff' : h.tint};flex:none;
         display:flex;align-items:center;justify-content:center">${icon(ic, 14, h.ink)}</div>
    <div style="flex:1;font-size:11px;font-weight:600;line-height:1.3;
         ${on ? `color:${H.violet.ink}` : ''}">${title}</div></div>`;

export const wClassroom = () => `${wcss}<div class="ws">${rail('Classroom')}
  <main class="wmain">
    <div class="wtop"><div><div class="wtitle">Chemistry</div>
      <div class="wsub">WAEC · 14 notes, 6 videos, 3 files</div></div>
      <div class="wrow" style="gap:6px"><span class="wchip on">WAEC</span>
        <span class="wchip">JAMB</span><span class="wchip">NECO</span></div></div>
    <div class="cols" style="gap:14px">
      <div style="flex:.85">
        <div class="wlbl">Notes to read</div>
        ${wrow(H.teal, 'doc', 'Periodicity and the modern periodic table')}
        ${wrow(H.teal, 'doc', 'Mole concept: moles, mass and Avogadro', true)}
        ${wrow(H.teal, 'doc', 'Redox reactions and oxidation numbers')}
        <div class="wlbl" style="margin-top:11px">Video lessons</div>
        ${wrow(H.rose, 'play', 'Balancing redox equations — worked examples')}
        <div class="wlbl" style="margin-top:11px">Files to keep</div>
        ${wrow(H.amber, 'doc', 'WAEC Chemistry formula sheet.pdf')}
      </div>
      <div style="flex:1.15">
        <div class="wcard" style="padding:15px 16px;box-shadow:0 4px 12px rgba(11,16,32,.05)">
          <div style="font-family:SG;font-weight:700;font-size:15px;letter-spacing:-.4px">
            Mole concept: moles, mass and Avogadro</div>
          <div style="font-size:11px;line-height:1.65;color:${C.t2};margin-top:10px;font-weight:450">
            One mole of any substance contains 6.02 × 10²³ particles — the Avogadro constant. The
            mass of one mole, in grams, is numerically equal to the relative molecular mass.<br><br>
            • <b>Moles = mass ÷ molar mass</b><br>
            • <b>Moles = volume ÷ 22.4 dm³</b> at s.t.p.<br>
            • <b>Moles = concentration × volume</b> in solution<br><br>
            Worked example: find the number of moles in 11 g of carbon(IV) oxide. The molar mass of
            CO₂ is 44 g/mol, so n = 11 ÷ 44 = 0.25 mol.</div>
          <div style="margin-top:13px;border-radius:11px;overflow:hidden;background:#0B1020;
               height:84px;display:flex;align-items:center;justify-content:center;gap:9px">
            <div style="width:34px;height:34px;border-radius:50%;background:rgba(255,255,255,.16);
                 display:flex;align-items:center;justify-content:center">
              ${icon('play', 15, '#fff')}</div>
            <span style="color:#fff;font-size:11px;font-weight:600">Video lesson · 8:42</span></div>
        </div>
      </div>
    </div>
  </main></div>`;

export const WIDE = [
  { n: 'home', headline: 'Every past question.<br>One app.',
    sub: 'JAMB, WAEC, NECO, NABTEB, GCE and Post-UTME — practice, notes, games and your real rank.',
    grad: 'linear-gradient(150deg,#3B6DF0 0%,#1D4ED8 46%,#12296B 100%)', inner: wHome },
  { n: 'practice', headline: 'Train the way<br>you will be tested.',
    sub: 'By year, by topic or a random mix. Open practice, or a clock that runs exactly like the hall.',
    grad: 'linear-gradient(150deg,#2F62E8 0%,#1B47C4 46%,#0F2C86 100%)', inner: wPractice },
  { n: 'sitting', headline: 'A real CBT,<br>down to the clock.',
    sub: 'A full 180-question UTME mock, four subjects, scored over 400 — with no answers until you submit.',
    grad: 'linear-gradient(150deg,#4C3BD6 0%,#3728B8 46%,#1E167A 100%)', inner: wSitting },
  { n: 'result', headline: 'Your score,<br>the second you submit.',
    sub: 'Broken down subject by subject, weakest first — then walk back through every question you missed.',
    grad: 'linear-gradient(150deg,#1C9A62 0%,#107A46 46%,#064F2B 100%)', inner: wResult },
  { n: 'analysis', headline: 'See where your<br>marks are going.',
    sub: 'Every paper plotted over time, and the exact topics costing you the most.',
    grad: 'linear-gradient(150deg,#4A3BD2 0%,#3728B8 46%,#211A72 100%)', inner: wAnalysis },
  { n: 'classroom', headline: 'Notes, videos<br>and files to keep.',
    sub: 'Written lessons and video explanations from your tutors, open side by side.',
    grad: 'linear-gradient(150deg,#8A3BD2 0%,#6B28B8 46%,#3F1570 100%)', inner: wClassroom },
];
