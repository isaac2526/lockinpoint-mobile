import { C, H, icon, statusbar } from './ui.mjs';

/* Every string below is lifted verbatim from the Dart source. LipLabel
   renders its text UPPERCASED in the app, so labels are uppercased here too. */

export const css = `<style>
  .body{font-family:IN,sans-serif;color:${C.t1}}
  .pad{padding:0 17px}
  .row{display:flex;align-items:center}
  .sp{justify-content:space-between}
  .mono{font-family:JB;font-weight:700;font-variant-numeric:tabular-nums}
  .topbar{height:50px;display:flex;align-items:center;justify-content:space-between;padding:0 17px}
  .appbar{height:52px;display:flex;align-items:center;gap:12px;padding:0 17px;
          font-family:SG;font-weight:700;font-size:18px;letter-spacing:-.4px}
  .iconbtn{width:34px;height:34px;border-radius:11px;background:#fff;border:1px solid ${C.border};
           display:flex;align-items:center;justify-content:center;position:relative}
  .dot{position:absolute;top:6px;right:7px;width:7px;height:7px;border-radius:50%;
       background:${C.danger};border:1.5px solid #fff}
  .avatar{width:34px;height:34px;border-radius:50%;background:linear-gradient(145deg,#4A79F2,#0F2C86);
          color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px}
  .wm{font-family:SG;font-weight:700;font-size:17px;letter-spacing:-.5px}
  .lbl{font-family:IN;font-weight:700;font-size:10px;letter-spacing:1.3px;color:${C.t3};
       text-transform:uppercase;margin:16px 0 8px}
  h2.hi{font-family:SG;font-weight:700;font-size:24px;letter-spacing:-.7px}
  .sub{color:${C.t3};font-size:13.5px;font-weight:500}
  .card{background:#fff;border:1px solid ${C.border};border-radius:18px}
  .deep{background:#F0F2F7;border:1px solid ${C.border};border-radius:16px}
  .sh{box-shadow:0 5px 16px rgba(11,16,32,.05)}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
  .tile{border-radius:18px;padding:12px 12px 13px}
  .tile .ti{width:34px;height:34px;border-radius:12px;background:rgba(255,255,255,.75);
            display:flex;align-items:center;justify-content:center}
  .tile h3{font-family:SG;font-weight:700;font-size:13.5px;margin-top:9px;letter-spacing:-.3px}
  .tile p{font-size:10.5px;line-height:1.35;margin-top:2px;font-weight:500;opacity:.8}
  .chip{display:inline-flex;align-items:center;gap:6px;height:31px;padding:0 13px;border-radius:999px;
        font-size:12.5px;font-weight:600;border:1px solid ${C.border};background:#fff;color:${C.t2}}
  .chip.on{background:${C.brand};border-color:${C.brand};color:#fff}
  .chip.gold{background:#FBF1DF;border-color:#EBD9A8;color:${C.accent}}
  .chip .ct{opacity:.6;font-family:JB;font-size:11px}
  .chips{display:flex;flex-wrap:wrap;gap:7px}
  .cc{display:flex;align-items:center;gap:11px;background:#fff;border:1px solid ${C.border};
      border-radius:17px;padding:12px 13px}
  .cc.on{border-color:${C.brand};box-shadow:0 0 0 1.5px ${C.brand}}
  .cc .ci{width:36px;height:36px;border-radius:12px;display:flex;align-items:center;justify-content:center}
  .cc h4{font-family:SG;font-weight:700;font-size:14px;letter-spacing:-.25px}
  .cc p{font-size:11px;color:${C.t3};margin-top:2px;font-weight:500;line-height:1.35}
  .btn{height:47px;border-radius:15px;background:${C.brand};color:#fff;display:flex;align-items:center;
       justify-content:center;gap:8px;font-weight:700;font-size:15px;font-family:SG;letter-spacing:-.2px;
       box-shadow:0 8px 18px rgba(29,78,216,.26)}
  .btn.gold{background:${C.gold};color:#241A00;box-shadow:0 8px 18px rgba(217,162,19,.3)}
  .btn.ghost{background:#fff;border:1px solid ${C.border};color:${C.t1};box-shadow:none}
  .bar{height:6px;border-radius:999px;background:#EDF0F6;overflow:hidden}
  .bar i{display:block;height:100%;border-radius:999px}
  .nav{position:absolute;bottom:0;left:0;right:0;height:68px;background:#fff;border-top:1px solid ${C.border};
       display:flex;align-items:flex-start;padding-top:10px}
  .nav div{flex:1;display:flex;flex-direction:column;align-items:center;gap:3px;
           font-size:10px;font-weight:600;color:${C.t3}}
  .nav div.on{color:${C.brand}}
  .nav .nb{width:52px;height:26px;border-radius:999px;display:flex;align-items:center;justify-content:center}
  .nav div.on .nb{background:${H.blue.tint}}
  .homebar{position:absolute;bottom:6px;left:50%;transform:translateX(-50%);width:116px;height:4px;
           border-radius:999px;background:rgba(11,16,32,.2);z-index:9}
  .fade{position:absolute;left:0;right:0;bottom:0;height:70px;z-index:8;
        background:linear-gradient(to bottom,rgba(246,247,251,0),${C.bg} 78%)}
  .stat{flex:1;border-radius:15px;background:#F0F2F7;border:1px solid ${C.border};
        padding:10px 8px;text-align:center}
  .stat b{font-family:JB;font-weight:700;font-size:17px;display:block}
  .stat span{font-size:9.5px;color:${C.t3};font-weight:600}
  .opt{display:flex;align-items:flex-start;gap:11px;background:#fff;border:1px solid ${C.border};
       border-radius:15px;padding:11px 12px;margin-bottom:8px;font-size:13px;line-height:1.4}
  .ol{width:25px;height:25px;border-radius:50%;flex:none;display:flex;align-items:center;
      justify-content:center;font-weight:700;font-size:12px;background:#EEF1F7;color:${C.t2}}
  .srow{display:flex;align-items:center;gap:9px;margin-bottom:10px;font-size:12px;font-weight:600}
  .srow .nm{flex:1}
</style>`;

const wordmark = (s = 17) =>
  `<span class="wm" style="font-size:${s}px">LockIn<span style="color:${C.brand}">Point</span></span>`;

const logomark = (s = 26) => `
  <div style="width:${s}px;height:${s}px;border-radius:${s * 0.28}px;flex:none;
       background:linear-gradient(145deg,#4A79F2,#0F2C86);display:flex;align-items:center;
       justify-content:center;color:#F7D269;font-family:SG;font-weight:700;font-size:${s * 0.46}px;
       box-shadow:0 2px 6px rgba(15,44,134,.3)">LP</div>`;

const tile = (h, name, title, sub) => `
  <div class="tile" style="background:${h.tint}">
    <div class="ti">${icon(name, 19, h.ink)}</div>
    <h3 style="color:${h.ink}">${title}</h3>
    <p style="color:${h.ink}">${sub}</p>
  </div>`;

const nav = (active) => {
  const items = [['home', 'Home'], ['rocket', 'Practice'], ['leaderboard', 'Ranking'], ['person', 'Profile']];
  return `<div class="nav">${items.map(([ic, lb], i) => `
    <div class="${i === active ? 'on' : ''}">
      <div class="nb">${icon(ic, 19, i === active ? C.brand : C.t3)}</div>${lb}
    </div>`).join('')}</div>`;
};

const cc = (h, ic, title, sub, on = false) => `
  <div class="cc ${on ? 'on' : ''}" style="margin-bottom:8px">
    <div class="ci" style="background:${h.tint}">${icon(ic, 18, h.ink)}</div>
    <div style="flex:1"><h4 style="${on ? `color:${C.brand}` : ''}">${title}</h4><p>${sub}</p></div>
  </div>`;

const sbar = (name, got, tot, pct, col) => `
  <div class="srow"><span class="nm">${name}</span>
    <span class="mono" style="font-size:11px;color:${C.t3}">${got}/${tot}</span>
    <span style="width:34px;text-align:right;color:${col}">${pct}%</span></div>
  <div class="bar" style="margin:-4px 0 11px"><i style="width:${pct}%;background:${col}"></i></div>`;

/* ======================================================= 1 · HOME ======= */
export const home = () => `${css}${statusbar()}
<div class="body">
  <div class="topbar">
    <div class="row" style="gap:9px">${icon('menu', 21, C.t2)}${wordmark()}</div>
    <div class="row" style="gap:8px">
      <div class="iconbtn">${icon('bell', 17, C.t2)}<span class="dot"></span></div>
      <div class="avatar">IA</div>
    </div>
  </div>
  <div class="pad">
    <div class="row sp">
      <h2 class="hi">Welcome back, Isaac</h2>
      <div style="display:flex;flex-direction:column;align-items:center;background:#FBF1DF;
                  border-radius:13px;padding:5px 10px">
        <div class="row" style="gap:3px">${icon('flame', 13, H.amber.ink)}
          <b class="mono" style="font-size:14px;color:${H.amber.ink}">12</b></div>
        <span style="font-size:8.5px;font-weight:600;color:${H.amber.ink}">day streak</span>
      </div>
    </div>

    <div class="card sh" style="margin-top:12px;padding:11px 12px;display:flex;align-items:center;gap:11px">
      <div style="width:38px;height:38px;border-radius:13px;background:${H.blue.tint};flex:none;
                  display:flex;align-items:center;justify-content:center">${icon('rocket', 19, H.blue.ink)}</div>
      <div style="flex:1">
        <div style="font-family:SG;font-weight:700;font-size:13px">Continue where you stopped</div>
        <div style="font-size:10.5px;color:${C.t3};margin-top:1px;font-weight:500">JAMB · Mathematics · Random mix</div>
        <div class="bar" style="margin-top:7px"><i style="width:45%;background:${C.brand}"></i></div>
        <div style="font-size:9.5px;color:${C.t3};margin-top:4px;font-weight:600">18 of 40 answered</div>
      </div>
      ${icon('chev', 16, C.t3)}
    </div>

    <div class="row" style="gap:8px;margin-top:11px">
      <div class="stat"><b>40.1k</b><span>questions live</span></div>
      <div class="stat"><b>37</b><span>sittings done</span></div>
      <div class="stat"><b>284</b><span>notes &amp; videos</span></div>
    </div>

    <div class="lbl">What are you doing today?</div>
    <div class="grid">
      ${tile(H.blue, 'rocket', 'Practice &amp; CBT', 'Real past questions, timed or open')}
      ${tile(H.violet, 'book', 'Classroom', 'Notes, materials and video lessons')}
      ${tile(H.indigo, 'insights', 'Performance analysis', 'Where your marks are going')}
      ${tile(H.purple, 'gamepad', 'Games arena', 'Blitz, Survival, The Climb')}
      ${tile(H.pink, 'leaderboard', 'Leaderboard', 'Your rank, nationally and locally')}
      ${tile(H.teal, 'bolt', 'Offline vault', 'Downloaded questions, no signal needed')}
      ${tile(H.amber, 'trophy', 'The Climb', 'Fifteen rungs, three lifelines')}
      ${tile(H.rose, 'robot', 'Ask Lumi', 'Your AI tutor, any question')}
    </div>
  </div>
  <div class="fade" style="bottom:68px"></div>
  ${nav(0)}<div class="homebar"></div>
</div>`;

/* ============================================ 2 · PRACTICE SET-UP ======= */
export const practice = () => `${css}${statusbar()}
<div class="body">
  <div class="row" style="gap:12px;padding:10px 17px 0">
    <div style="transform:rotate(180deg)">${icon('chev', 20, C.t2)}</div>
    <div><div style="font-family:SG;font-weight:700;font-size:19px;letter-spacing:-.5px">Mathematics</div>
      <div class="sub" style="font-size:11.5px">Step 3 of 3</div></div>
  </div>
  <div class="pad" style="margin-top:12px">
    ${cc(H.blue, 'shuffle', 'Random mix', 'A spread across every year', true)}
    ${cc(H.blue, 'cal', 'By year', 'One real past paper year')}
    ${cc(H.blue, 'layers', 'By topic', 'Drill one topic until it yields')}

    <div class="lbl">Keep Mathematics on your phone</div>
    <div class="row" style="gap:8px;border:1px solid ${C.border};background:#fff;border-radius:15px;
         padding:11px 13px">
      <div style="width:32px;height:32px;border-radius:11px;background:${H.teal.tint};flex:none;
           display:flex;align-items:center;justify-content:center">${icon('down', 16, H.teal.ink)}</div>
      <div style="flex:1;font-size:12.5px;font-weight:700;font-family:SG">Download for offline</div>
      <span class="chip" style="height:26px;font-size:10.5px;padding:0 10px">420 questions</span>
    </div>

    <div class="lbl">How many questions</div>
    <div class="chips">
      <span class="chip">10</span><span class="chip">20</span><span class="chip on">40</span>
      <span class="chip">60</span><span class="chip">100</span><span class="chip">Other</span>
    </div>

    <div class="lbl">How do you want to sit it</div>
    ${cc(H.slate, 'play', 'Practice', 'No clock. See the answer and the why after each question')}
    ${cc(H.amber, 'clock', 'CBT', 'A clock, no answers until you submit, exactly like the hall', true)}

    <div class="lbl">How long</div>
    <div class="chips">
      <span class="chip">10 min</span><span class="chip">20 min</span><span class="chip on">30 min</span>
      <span class="chip">45 min</span><span class="chip">60 min</span><span class="chip">120 min</span>
    </div>

    <div class="deep" style="margin-top:15px;padding:11px 13px;font-size:12px;font-weight:600;color:${C.t2}">
      JAMB · Mathematics · Random mix · CBT
    </div>
    <div class="btn gold" style="margin-top:11px">${icon('clock', 17, '#241A00')} Start the clock</div>
  </div>
  <div class="homebar"></div>
</div>`;

/* ================================================ 3 · CBT SITTING ======= */
export const sitting = () => `${css}${statusbar()}
<div class="body">
  <div class="row" style="gap:10px;padding:8px 15px 0">
    ${icon('cross', 19, C.t2)}
    <div style="flex:1">
      <div style="font-family:SG;font-weight:700;font-size:12.5px;letter-spacing:-.2px">JAMB mock · 4 subjects</div>
      <div style="font-size:10px;color:${C.t3};font-weight:500">Question 47 of 180 · 44 answered</div>
    </div>
    <div class="row" style="gap:5px;background:#FBF1DF;border:1px solid #EBD9A8;border-radius:999px;
         padding:5px 11px"><span>${icon('clock', 13, H.amber.ink)}</span>
      <b class="mono" style="font-size:13px;color:${H.amber.ink}">54:12</b></div>
    ${icon('grid4', 18, C.t2)}
    <span style="font-family:SG;font-weight:700;font-size:13px;color:${C.brand}">Submit</span>
  </div>

  <div class="row" style="gap:7px;padding:11px 15px 0;overflow:hidden">
    <span class="chip" style="height:28px;font-size:11px">Use of English</span>
    <span class="chip on" style="height:28px;font-size:11px">Mathematics</span>
    <span class="chip" style="height:28px;font-size:11px">Physics</span>
    <span class="chip" style="height:28px;font-size:11px">Chem</span>
  </div>
  <div style="height:3px;background:#E7EBF3;margin-top:10px"><div style="width:26%;height:100%;background:${C.brand}"></div></div>

  <div class="pad" style="margin-top:12px">
    <div class="row" style="gap:7px">
      <span class="chip" style="height:26px;font-size:11px">2021</span>
      <span class="chip" style="height:26px;font-size:11px">Algebra</span>
      <span style="flex:1"></span>
      <span class="chip gold" style="height:26px;font-size:11px">Flagged</span>
    </div>

    <div class="card sh" style="margin-top:11px;padding:16px">
      <div style="font-size:15px;line-height:1.55;font-weight:500">
        A trader bought 120 oranges at ₦25 each. She sold two-thirds of them at ₦40 each and the
        remainder at ₦30 each. Find her percentage profit, correct to one decimal place.
      </div>
      <div class="row" style="gap:16px;margin-top:14px;padding-top:12px;border-top:1px solid ${C.border}">
        ${icon('bookmark', 17, C.t3)}${icon('speaker', 17, C.t3)}${icon('robot', 17, C.t3)}
      </div>
    </div>

    <div style="margin-top:13px">
      <div class="opt" style="padding:16px 13px"><div class="ol">A</div><div>21.3%</div></div>
      <div class="opt" style="padding:16px 13px;border-color:${C.brand};box-shadow:0 0 0 1.5px ${C.brand}">
        <div class="ol" style="background:${C.brand};color:#fff">B</div><div>46.7%</div></div>
      <div class="opt" style="padding:16px 13px"><div class="ol">C</div><div>33.3%</div></div>
      <div class="opt" style="padding:16px 13px"><div class="ol">D</div><div>52.0%</div></div>
    </div>

    <div class="deep" style="margin-top:4px;padding:11px 13px;font-size:11px;font-weight:600;
         color:${C.t3};line-height:1.4">
      No answers until you submit — exactly like the hall.
    </div>
  </div>

  <div style="position:absolute;bottom:0;left:0;right:0;background:#fff;border-top:1px solid ${C.border};
       padding:11px 15px 20px;display:flex;align-items:center;gap:10px">
    <div style="width:44px;height:44px;border-radius:14px;background:#EEF1F7;display:flex;
         align-items:center;justify-content:center;transform:rotate(180deg)">${icon('chev', 18, C.t2)}</div>
    <div class="btn" style="flex:1;height:44px">Next question</div>
    <span class="mono" style="font-size:12px;color:${C.t3}">47/180</span>
  </div>
  <div class="homebar"></div>
</div>`;

/* ===================================================== 4 · RESULT ======= */
export const result = () => `${css}${statusbar()}
<div class="body" style="text-align:center;display:flex;flex-direction:column;justify-content:center">
  <div class="pad" style="padding-bottom:24px">
    <div style="width:134px;height:134px;border-radius:50%;margin:0 auto;border:3px solid ${C.success};
         display:flex;flex-direction:column;align-items:center;justify-content:center">
      <b class="mono" style="font-size:42px;color:${C.success};line-height:1">265</b>
    </div>
    <div style="font-size:12.5px;color:${C.t3};font-weight:600;margin-top:10px">out of 400</div>
    <div style="font-family:SG;font-weight:700;font-size:23px;margin-top:16px;letter-spacing:-.5px">
      Sharp. Keep this pace.</div>
    <div style="font-size:13px;color:${C.t3};font-weight:500;margin-top:7px;line-height:1.45">
      119 of 180 correct · JAMB mock</div>

    <div class="card" style="margin-top:20px;padding:16px 16px 6px;text-align:left">
      ${sbar('Use of English', 42, 60, 70, C.success)}
      ${sbar('Mathematics', 28, 40, 70, C.success)}
      ${sbar('Physics', 27, 40, 68, H.amber.ink)}
      ${sbar('Chemistry', 22, 40, 55, H.amber.ink)}
    </div>

    <div class="btn gold" style="margin-top:18px">${icon('check', 17, '#241A00')} See what you missed</div>
    <div class="btn ghost" style="margin-top:10px">${icon('home', 16, C.t1)} Back to the dashboard</div>
  </div>
  <div class="homebar"></div>
</div>`;

/* =================================================== 5 · ANALYSIS ======= */
const spark = () => {
  const pts = [38, 46, 42, 55, 61, 58, 70, 74, 81];
  const W = 338, Hh = 118;
  const xy = pts.map((v, i) => [12 + (i * (W - 24)) / (pts.length - 1), Hh - (v / 100) * (Hh - 10) - 4]);
  const line = xy.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const area = `${line} L${xy.at(-1)[0].toFixed(1)} ${Hh} L${xy[0][0].toFixed(1)} ${Hh} Z`;
  const grid = [0, 25, 50, 75, 100].map((g) => {
    const y = Hh - (g / 100) * (Hh - 10) - 4;
    return `<line x1="26" y1="${y.toFixed(1)}" x2="${W}" y2="${y.toFixed(1)}" stroke="#E7EBF3" stroke-width="1"/>
            <text x="0" y="${(y + 3.5).toFixed(1)}" font-size="9" fill="${C.t3}" font-family="IN">${g}</text>`;
  }).join('');
  return `<svg width="${W}" height="${Hh}" viewBox="0 0 ${W} ${Hh}">
    ${grid}
    <path d="${area}" fill="${H.indigo.ink}" opacity=".10"/>
    <path d="${line}" fill="none" stroke="${H.indigo.ink}" stroke-width="2.6"
          stroke-linecap="round" stroke-linejoin="round"/>
    ${xy.map((p) => `<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="3.4"
          fill="#fff" stroke="${H.indigo.ink}" stroke-width="2.2"/>`).join('')}
  </svg>`;
};

const topic = (name, pct, seen, tot, subj, col) => `
  <div style="margin-bottom:11px">
    <div class="row sp" style="font-size:12px;font-weight:600"><span>${name}</span>
      <b style="color:${col}">${pct}%</b></div>
    <div class="bar" style="margin-top:5px"><i style="width:${pct}%;background:${col}"></i></div>
    <div style="font-size:9.5px;color:${C.t3};margin-top:4px;font-weight:500">${seen} of ${tot} · ${subj}</div>
  </div>`;

export const analysis = () => `${css}${statusbar()}
<div class="body">
  <div class="appbar"><div style="transform:rotate(180deg)">${icon('chev', 19, C.t2)}</div>Performance analysis</div>
  <div class="pad">
    <div style="display:flex;gap:10px;background:${H.indigo.tint};border-radius:16px;padding:12px 13px">
      <div style="flex:none">${icon('bulb', 18, H.indigo.ink)}</div>
      <div style="font-size:11.5px;line-height:1.45;font-weight:500;color:${H.indigo.ink}">
        Your Chemistry has climbed 14 points in three papers. Quadratic Equations is now the one costing you most.
      </div>
    </div>

    <div class="lbl">Score over time</div>
    <div class="card" style="padding:12px 12px 8px">${spark()}
      <div style="font-size:9.5px;color:${C.t3};line-height:1.45;margin-top:6px;font-weight:500">
        9 papers, oldest on the left. The scale runs 0 to 100 — a percentage cannot go below zero,
        so the axis does not either.</div>
    </div>

    <div class="lbl">Topic by topic</div>
    <div style="background:${H.indigo.tint};border-radius:16px;padding:13px 14px 4px">
      <div style="font-family:SG;font-weight:700;font-size:13px;color:${H.indigo.ink};margin-bottom:10px">
        Revise these first</div>
      ${topic('Quadratic Equations', 22, 4, 18, 'Mathematics', C.danger)}
      ${topic('Mole Concept', 35, 7, 20, 'Chemistry', C.danger)}
      ${topic('Vectors', 48, 11, 23, 'Physics', H.amber.ink)}
    </div>
    <div class="card" style="margin-top:10px;padding:13px 14px 4px">
      <div style="font-family:SG;font-weight:700;font-size:13px;margin-bottom:10px">Solid ground</div>
      ${topic('Comprehension', 88, 22, 25, 'Use of English', C.success)}
      ${topic('Indices &amp; Logarithms', 81, 17, 21, 'Mathematics', C.success)}
    </div>
  </div>
  <div class="fade"></div><div class="homebar"></div>
</div>`;

/* ================================================== 6 · CLASSROOM ======= */
const shelfRow = (h, ic, title) => `
  <div class="row" style="gap:11px;background:#fff;border:1px solid ${C.border};border-radius:15px;
       padding:11px 12px;margin-bottom:8px">
    <div style="width:33px;height:33px;border-radius:11px;background:${h.tint};flex:none;
         display:flex;align-items:center;justify-content:center">${icon(ic, 16, h.ink)}</div>
    <div style="flex:1;font-size:12.5px;font-weight:600;line-height:1.35">${title}</div>
    ${icon('chev', 15, C.t3)}
  </div>`;

export const classroom = () => `${css}${statusbar()}
<div class="body">
  <div class="appbar"><div style="transform:rotate(180deg)">${icon('chev', 19, C.t2)}</div>Chemistry</div>
  <div class="pad">
    <div class="row" style="gap:7px;margin-bottom:4px">
      <span class="chip on" style="height:29px;font-size:11.5px">WAEC</span>
      <span class="chip" style="height:29px;font-size:11.5px">JAMB</span>
      <span class="chip" style="height:29px;font-size:11.5px">NECO</span>
      <span class="chip" style="height:29px;font-size:11.5px">NABTEB</span>
    </div>

    <div class="lbl">Notes to read</div>
    ${shelfRow(H.teal, 'doc', 'Periodicity and the modern periodic table')}
    ${shelfRow(H.teal, 'doc', 'Mole concept: moles, mass and the Avogadro constant')}
    ${shelfRow(H.teal, 'doc', 'Redox reactions and oxidation numbers')}

    <div class="lbl">Video lessons</div>
    ${shelfRow(H.rose, 'play', 'Balancing redox equations — worked examples')}
    ${shelfRow(H.rose, 'play', 'Titration calculations, step by step')}

    <div class="lbl">Files to keep</div>
    ${shelfRow(H.amber, 'doc', 'WAEC Chemistry formula sheet.pdf')}
    ${shelfRow(H.amber, 'doc', 'Qualitative analysis tables.pdf')}
  </div>
  <div class="fade"></div><div class="homebar"></div>
</div>`;

/* ====================================================== 7 · VAULT ======= */
const pack = (subj, line) => `
  <div class="row" style="gap:11px;background:#fff;border:1px solid ${C.border};border-radius:17px;
       padding:12px 13px;margin-bottom:9px">
    <div style="width:44px;height:44px;border-radius:14px;background:${H.teal.tint};flex:none;
         display:flex;align-items:center;justify-content:center">${icon('bolt', 22, H.teal.ink)}</div>
    <div style="flex:1">
      <div style="font-family:SG;font-weight:700;font-size:14px;letter-spacing:-.25px">${subj}</div>
      <div style="font-size:10.5px;color:${C.t3};margin-top:2px;font-weight:500">${line}</div>
    </div>
    ${icon('cross', 15, C.t3)}
  </div>`;

export const vault = () => `${css}${statusbar()}
<div class="body">
  <div class="appbar"><div style="transform:rotate(180deg)">${icon('chev', 19, C.t2)}</div>Offline vault</div>
  <div class="pad">
    <div class="row" style="gap:9px;background:${H.green.tint};border-radius:14px;padding:11px 12px;
         margin-bottom:13px">
      ${icon('wifioff', 16, H.green.ink)}
      <div style="font-size:11px;font-weight:600;color:${H.green.ink};line-height:1.35">
        No connection — tap here: your downloaded questions still work</div>
    </div>

    ${pack('Mathematics', 'JAMB · 420 questions · tap to practise')}
    ${pack('Chemistry', 'WAEC · 240 questions · tap to practise')}
    ${pack('Use of English', 'JAMB · 380 questions · tap to practise')}
    ${pack('Physics', 'WAEC · 196 questions · tap to practise')}
    ${pack('Biology', 'NECO · 305 questions · tap to practise')}

    <div style="font-size:10.5px;color:${C.t3};text-align:center;line-height:1.5;
         padding:6px 10px 0;font-weight:500">
      Downloaded questions are answered and marked on this phone. Your results are sent to
      LockInPoint the next time you have a connection.</div>
  </div>
  <div class="fade"></div><div class="homebar"></div>
</div>`;

/* ================================================== 8 · THE CLIMB ======= */
export const climb = () => `${css}${statusbar()}
<div class="body">
  <div class="row sp appbar"><div class="row" style="gap:12px">
      <div style="transform:rotate(180deg)">${icon('chev', 19, C.t2)}</div>Rung 9 of 15</div>
    <span style="font-family:SG;font-weight:700;font-size:13px;color:${C.t2}">Walk</span></div>
  <div class="pad">
    <div class="row" style="gap:8px">
      <div class="stat"><b style="color:${H.amber.ink}">290</b><span>points</span></div>
      <div class="stat"><b style="color:${C.success}">150</b><span>banked</span></div>
      <div class="stat"><b style="color:${C.gold}">12</b><span>second net</span></div>
    </div>

    <div class="card sh" style="margin-top:14px;padding:16px">
      <div style="font-size:15px;line-height:1.55;font-weight:500">
        Which of these gases diffuses fastest at the same temperature and pressure?
      </div>
    </div>

    <div style="margin-top:13px">
      <div class="opt" style="padding:15px 13px"><div class="ol">A</div><div style="flex:1">Carbon(IV) oxide</div>
        <span class="chip" style="height:22px;font-size:10px;padding:0 8px">9%</span></div>
      <div class="opt" style="padding:15px 13px"><div class="ol">B</div><div style="flex:1">Oxygen</div>
        <span class="chip" style="height:22px;font-size:10px;padding:0 8px">17%</span></div>
      <div class="opt" style="padding:15px 13px"><div class="ol">C</div><div style="flex:1">Hydrogen</div>
        <span class="chip" style="height:22px;font-size:10px;padding:0 8px">62%</span></div>
      <div class="opt" style="padding:15px 13px"><div class="ol">D</div><div style="flex:1">Nitrogen</div>
        <span class="chip" style="height:22px;font-size:10px;padding:0 8px">12%</span></div>
    </div>

    <div class="deep" style="padding:12px 13px;font-size:11.5px;font-weight:600;color:${C.t2};
         line-height:1.4">How 312 students answered this one.</div>

    <div class="lbl">Lifelines</div>
    <div class="chips">
      <span class="chip gold">Fifty-fifty</span>
      <span class="chip gold">Ask the class</span>
      <span class="chip gold">Ask Lumi</span>
      <span class="chip on">Place second net</span>
    </div>

    <div style="margin-top:16px;background:${H.amber.tint};border-radius:15px;padding:12px 13px;
         display:flex;gap:10px">
      <div style="flex:none">${icon('trophy', 17, H.amber.ink)}</div>
      <div style="font-size:11px;line-height:1.45;font-weight:500;color:${H.amber.ink}">
        Clear rung five and you keep those points whatever happens after. Somewhere above that you
        place a second net yourself — and once placed it cannot move.</div>
    </div>
  </div>
  <div class="homebar"></div>
</div>`;
