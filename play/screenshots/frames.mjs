import { C } from './ui.mjs';
import { WIDE_W, WIDE_H } from './wide.mjs';

/* =============================================================================
   WIDE FRAMES. One 872x572 screen, three housings:
     tablet   · a bezelled slate
     desktop  · a window with a title bar
     xr       · a pane floating in space
   Canvas is 1280x720 CSS; the capture scale decides the final pixels, so the
   same markup yields 2560x1440, 3200x1800 or 2880x1620 without relayout.
   ========================================================================== */

const FONTS = `
  @font-face{font-family:SG;src:url(assets/SpaceGrotesk-Bold.ttf);font-weight:700}
  @font-face{font-family:SG;src:url(assets/SpaceGrotesk-SemiBold.ttf);font-weight:600}
  @font-face{font-family:SG;src:url(assets/SpaceGrotesk-Medium.ttf);font-weight:500}
  @font-face{font-family:IN;src:url(assets/Inter-Bold.ttf);font-weight:700}
  @font-face{font-family:IN;src:url(assets/Inter-SemiBold.ttf);font-weight:600}
  @font-face{font-family:IN;src:url(assets/Inter-Medium.ttf);font-weight:500}
  @font-face{font-family:IN;src:url(assets/Inter-Regular.ttf);font-weight:400}
  @font-face{font-family:JB;src:url(assets/JetBrainsMono-Bold.ttf);font-weight:700}`;

/* The slate is scaled to sit fully inside the canvas rather than bleeding:
   a cropped tablet hides the second column, which is the whole point of the
   wide layout. */
const SCALE = 0.9;

const tabletFrame = (inner) => `
  <div class="frame tablet">
    <div class="glass">${inner}</div>
    <div class="cam"></div>
  </div>`;

const desktopFrame = (inner) => `
  <div class="frame desktop">
    <div class="titlebar">
      <span class="tl" style="background:#FF5F57"></span>
      <span class="tl" style="background:#FEBC2E"></span>
      <span class="tl" style="background:#28C840"></span>
      <span class="tt">LockInPoint</span>
    </div>
    <div class="glass desk">${inner}</div>
  </div>`;

const xrFrame = (inner) => `
  <div class="frame xr">
    <div class="glass xrglass">${inner}</div>
  </div>`;

const FRAMES = { tablet: tabletFrame, desktop: desktopFrame, xr: xrFrame };

export const widePage = ({ kind, headline, sub, grad, inner }) => {
  const xr = kind === 'xr';
  const bg = xr
    ? `radial-gradient(85% 60% at 50% 8%, #26306B 0%, #121735 42%, #06080F 100%)`
    : grad;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  ${FONTS}
  *{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}
  body{width:1280px;height:720px;overflow:hidden;font-family:IN,sans-serif;background:${bg};
       position:relative}
  .vig{position:absolute;inset:0;background:
    radial-gradient(110% 60% at 50% 0%, rgba(255,255,255,${xr ? '.10' : '.18'}), transparent 62%),
    radial-gradient(80% 45% at 50% 100%, rgba(0,0,0,.26), transparent 62%)}
  ${xr ? `
  .orb{position:absolute;border-radius:50%;filter:blur(60px);opacity:.55}
  .o1{width:420px;height:420px;left:-90px;top:120px;background:#2F62E8}
  .o2{width:360px;height:360px;right:-70px;top:-60px;background:#6B28B8}
  .o3{width:300px;height:300px;left:52%;bottom:-130px;background:#186C6F}
  .star{position:absolute;width:2px;height:2px;border-radius:50%;background:#fff;opacity:.5}` : ''}
  .cap{position:absolute;top:40px;left:0;right:0;text-align:center;padding:0 90px;z-index:4}
  .cap h1{font-family:SG;font-weight:700;font-size:40px;line-height:1.1;letter-spacing:-1.1px;
          color:#fff;text-shadow:0 2px 16px rgba(0,0,0,.22)}
  .cap p{margin-top:11px;font-size:16px;line-height:1.4;font-weight:500;color:rgba(255,255,255,.80)}
  .stage{position:absolute;top:168px;left:0;right:0;display:flex;justify-content:center;z-index:3}
  .frame{transform:scale(${SCALE});transform-origin:top center}
  .glass{width:${WIDE_W}px;height:${WIDE_H}px;overflow:hidden;background:${C.bg}}

  .tablet{width:${WIDE_W + 26}px;border-radius:26px;padding:13px;position:relative;
    background:linear-gradient(155deg,#3A3F4B 0%,#1B1E25 40%,#0E1014 72%,#2B303A 100%);
    box-shadow:0 2px 0 rgba(255,255,255,.16) inset,0 46px 84px rgba(0,0,0,.44),
               0 16px 32px rgba(0,0,0,.30),0 0 0 1px rgba(0,0,0,.35)}
  .tablet .glass{border-radius:15px}
  .cam{position:absolute;left:6.5px;top:50%;transform:translateY(-50%);width:6px;height:6px;
       border-radius:50%;background:#05070A;box-shadow:0 0 0 1.3px rgba(255,255,255,.07)}

  .desktop{width:${WIDE_W}px;border-radius:13px;overflow:hidden;
    box-shadow:0 46px 84px rgba(0,0,0,.44),0 16px 32px rgba(0,0,0,.30),
               0 0 0 1px rgba(0,0,0,.22)}
  .titlebar{height:34px;background:linear-gradient(#F4F5F8,#E8EAF0);
    border-bottom:1px solid #D7DBE4;display:flex;align-items:center;gap:7px;padding:0 13px;
    position:relative}
  .tl{width:11px;height:11px;border-radius:50%;display:block}
  .tt{position:absolute;left:0;right:0;text-align:center;font-size:11.5px;font-weight:600;
      color:${C.t3};font-family:SG}
  .desk{height:${WIDE_H - 34}px}

  .xr{width:${WIDE_W + 16}px;border-radius:22px;padding:8px;
    background:linear-gradient(150deg,rgba(255,255,255,.26),rgba(255,255,255,.06));
    box-shadow:0 0 0 1px rgba(255,255,255,.22) inset,0 40px 90px rgba(0,0,0,.55),
               0 0 120px rgba(120,160,255,.30)}
  .xrglass{border-radius:15px}
  </style></head><body>
  ${xr ? `<div class="orb o1"></div><div class="orb o2"></div><div class="orb o3"></div>
    ${Array.from({ length: 70 }, (_, i) => {
      const x = (i * 97) % 1280, y = (i * 231) % 700, s = i % 3 === 0 ? 2.5 : 1.6;
      return `<div class="star" style="left:${x}px;top:${y}px;width:${s}px;height:${s}px"></div>`;
    }).join('')}` : ''}
  <div class="vig"></div>
  <div class="cap"><h1>${headline}</h1><p>${sub}</p></div>
  <div class="stage">${FRAMES[kind](inner)}</div>
  </body></html>`;
};

/* =============================================================================
   FEATURE GRAPHIC · 1024x500.
   Play crops and overlays this at several sizes, and on some surfaces drops a
   play button dead centre, so the type is held to the left third and nothing
   load-bearing sits in the middle.
   ========================================================================== */
export const featurePage = () => `<!doctype html><html><head><meta charset="utf-8"><style>
  ${FONTS}
  *{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}
  body{width:1024px;height:500px;overflow:hidden;position:relative;font-family:IN,sans-serif;
       background:linear-gradient(118deg,#1B46C4 0%,#1D4ED8 34%,#1A3AA8 62%,#0D2160 100%)}
  .glow{position:absolute;border-radius:50%;filter:blur(70px)}
  .g1{width:420px;height:420px;left:-120px;top:-130px;background:#4A79F2;opacity:.55}
  .g2{width:340px;height:340px;right:120px;bottom:-150px;background:#6B28B8;opacity:.40}
  .g3{width:260px;height:260px;right:-60px;top:-60px;background:#D9A213;opacity:.22}
  .sheen{position:absolute;inset:0;background:
    radial-gradient(70% 90% at 12% 22%, rgba(255,255,255,.17), transparent 60%)}
  .wrap{position:absolute;inset:0;display:flex;align-items:center;padding:0 54px;z-index:3}
  .left{width:560px}
  .brandrow{display:flex;align-items:center;gap:13px;margin-bottom:22px}
  .mark{width:62px;height:62px;border-radius:17px;flex:none;position:relative;
        background:linear-gradient(145deg,#4A79F2,#0F2C86);
        box-shadow:0 10px 26px rgba(4,16,56,.5),0 0 0 1.5px rgba(247,210,105,.55) inset;
        display:flex;align-items:center;justify-content:center}
  .mark b{font-family:SG;font-weight:700;font-size:28px;letter-spacing:-1px;
          background:linear-gradient(#F7D269,#C98F1B);-webkit-background-clip:text;
          -webkit-text-fill-color:transparent}
  .wm{font-family:SG;font-weight:700;font-size:40px;letter-spacing:-1.3px;color:#fff;line-height:1}
  .wm i{font-style:normal;color:#F7D269}
  .by{font-size:12px;color:rgba(255,255,255,.62);font-weight:500;margin-top:5px}
  h1{font-family:SG;font-weight:700;font-size:46px;line-height:1.08;letter-spacing:-1.5px;
     color:#fff;text-shadow:0 2px 18px rgba(0,0,0,.2)}
  .tag{margin-top:14px;font-size:17px;font-weight:500;color:rgba(255,255,255,.84);line-height:1.4}
  .exams{margin-top:22px;display:flex;flex-wrap:wrap;gap:7px}
  .ex{height:30px;padding:0 13px;border-radius:999px;display:flex;align-items:center;
      font-size:12.5px;font-weight:700;font-family:SG;letter-spacing:.1px;color:#fff;
      background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.26)}
  .right{position:absolute;right:-6px;top:0;bottom:0;width:430px;display:flex;align-items:center;
         justify-content:center}
  .slab{width:214px;height:430px;border-radius:30px;padding:8px;position:absolute;
    background:linear-gradient(160deg,#3A3F4B,#15171D 46%,#0E1014);
    box-shadow:0 34px 70px rgba(0,0,0,.5),0 0 0 1px rgba(0,0,0,.4),
               0 2px 0 rgba(255,255,255,.15) inset}
  .slab .sc{width:100%;height:100%;border-radius:23px;background:#F6F7FB;overflow:hidden;
            padding:14px 12px}
  .a{right:214px;transform:rotate(-8deg) scale(.88);opacity:.96}
  .b{right:48px;transform:rotate(5deg)}
  .mini{border-radius:11px;padding:9px 9px 10px;margin-bottom:7px}
  .mini b{font-family:SG;font-weight:700;font-size:10px;display:block;margin-top:6px}
  .mini i{display:block;width:20px;height:20px;border-radius:7px;background:rgba(255,255,255,.8)}
  .mh{font-family:SG;font-weight:700;font-size:13px;letter-spacing:-.4px;color:#0B1020}
  .ms{font-size:8.5px;color:#6C7690;font-weight:500;margin:2px 0 10px}
  .ring{width:96px;height:96px;border-radius:50%;border:3px solid #107A46;margin:22px auto 8px;
        display:flex;align-items:center;justify-content:center;font-family:JB;font-weight:700;
        font-size:30px;color:#107A46}
  .cen{text-align:center;font-size:9px;color:#6C7690;font-weight:600}
  .lin{height:6px;border-radius:999px;background:#EDF0F6;margin:9px 0 7px;overflow:hidden}
  .lin s{display:block;height:100%;border-radius:999px}
</style></head><body>
  <div class="glow g1"></div><div class="glow g2"></div><div class="glow g3"></div>
  <div class="sheen"></div>

  <div class="right">
    <div class="slab a"><div class="sc">
      <div class="mh">Welcome back</div><div class="ms">What are you doing today?</div>
      <div class="mini" style="background:#DFE9FB"><i></i><b style="color:#2759B0">Practice &amp; CBT</b></div>
      <div class="mini" style="background:#ECDFFB"><i></i><b style="color:#6B28B8">Classroom</b></div>
      <div class="mini" style="background:#DFFAFB"><i></i><b style="color:#186C6F">Offline vault</b></div>
      <div class="mini" style="background:#FBF1DF"><i></i><b style="color:#7D5A1C">The Climb</b></div>
    </div></div>
    <div class="slab b"><div class="sc">
      <div class="ring">265</div>
      <div class="cen">out of 400</div>
      <div style="font-family:SG;font-weight:700;font-size:13px;text-align:center;margin-top:11px;
           color:#0B1020;letter-spacing:-.3px">Sharp. Keep this pace.</div>
      <div style="margin-top:16px">
        <div style="font-size:9px;font-weight:600;color:#0B1020">Use of English</div>
        <div class="lin"><s style="width:70%;background:#107A46"></s></div>
        <div style="font-size:9px;font-weight:600;color:#0B1020">Mathematics</div>
        <div class="lin"><s style="width:70%;background:#107A46"></s></div>
        <div style="font-size:9px;font-weight:600;color:#0B1020">Physics</div>
        <div class="lin"><s style="width:68%;background:#7D5A1C"></s></div>
        <div style="font-size:9px;font-weight:600;color:#0B1020">Chemistry</div>
        <div class="lin"><s style="width:55%;background:#7D5A1C"></s></div>
      </div>
    </div></div>
  </div>

  <div class="wrap"><div class="left">
    <div class="brandrow">
      <div class="mark"><b>LP</b></div>
      <div><div class="wm">LockIn<i>Point</i></div>
        <div class="by">by Noesis Innovations</div></div>
    </div>
    <h1>Lock in.<br>Pass everything.</h1>
    <div class="tag">Real past questions, CBT mocks, tutor notes<br>and an AI tutor — online or offline.</div>
    <div class="exams">
      <span class="ex">JAMB</span><span class="ex">WAEC</span><span class="ex">NECO</span>
      <span class="ex">NABTEB</span><span class="ex">GCE</span><span class="ex">Post-UTME</span>
    </div>
  </div></div>
</body></html>`;
