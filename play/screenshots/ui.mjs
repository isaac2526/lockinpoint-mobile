/* =============================================================================
   LOCKINPOINT · PLAY STORE SCREENSHOT FRAMEWORK
   Palette and copy are lifted verbatim from the app:
     lib/design/tokens.dart          (LipColors.light, LipHues.lightSet)
     lib/features/home/feature_catalogue.dart
   Canvas is 720x1280 CSS rendered at deviceScaleFactor 2 => 1440x2560 (9:16).
   ========================================================================== */

export const C = {
  bg: '#F6F7FB', card: '#FFFFFF', border: '#E4E8F1',
  t1: '#0B1020', t2: '#414B63', t3: '#6C7690',
  brand: '#1D4ED8', brandStrong: '#12296B',
  gold: '#D9A213', accent: '#8A6100',
  success: '#107A46', danger: '#B42318', warning: '#B25A09',
};

// LipHues.lightSet — tint (fill) and ink (icon/title on that fill)
export const H = {
  blue:   { tint: '#DFE9FB', ink: '#2759B0' },
  indigo: { tint: '#E2DFFB', ink: '#3728B8' },
  violet: { tint: '#ECDFFB', ink: '#6B28B8' },
  purple: { tint: '#F6DFFB', ink: '#9126AB' },
  pink:   { tint: '#FBDFED', ink: '#A52465' },
  rose:   { tint: '#FBE0DF', ink: '#A92A25' },
  orange: { tint: '#FBEADF', ink: '#904D20' },
  amber:  { tint: '#FBF1DF', ink: '#7D5A1C' },
  lime:   { tint: '#EEFBDF', ink: '#466F18' },
  green:  { tint: '#DFFBED', ink: '#197145' },
  teal:   { tint: '#DFFAFB', ink: '#186C6F' },
  slate:  { tint: '#EEEFF1', ink: '#555F75' },
};

/* Icons drawn to match the Material Symbols Rounded glyphs the app names in
   feature_catalogue.dart. 24x24 box, solid fills, so they stay crisp at 2x. */
export const I = {
  rocket: `<path fill-rule="evenodd" d="M12 2.1c.28 0 .55.11.74.32 2.2 2.4 3.42 5.52 3.42 8.76v2.49l1.52 1.52c.37.37.58.88.58 1.41v2.93c0 .79-.87 1.27-1.54.85l-2.4-1.52h-4.64l-2.4 1.52c-.67.42-1.54-.06-1.54-.85V16.6c0-.53.21-1.04.58-1.41l1.52-1.52v-2.49c0-3.24 1.22-6.36 3.42-8.76.19-.21.46-.32.74-.32Zm0 4.92a2.05 2.05 0 1 0 0 4.1 2.05 2.05 0 0 0 0-4.1Z"/>`,
  book: `<path d="M11 5.4C9.6 4.5 7.9 4 6 4c-1 0-2 .1-2.9.4-.4.1-.6.4-.6.8V18c0 .5.5.9 1 .8.8-.2 1.6-.3 2.5-.3 1.8 0 3.4.5 4.7 1.3.2.1.4.2.6.2V5.6a1 1 0 0 0-.3-.2Zm2 0a1 1 0 0 0-.3.2V20c.2 0 .4 0 .6-.2 1.3-.8 2.9-1.3 4.7-1.3.9 0 1.7.1 2.5.3.5.1 1-.3 1-.8V5.2c0-.4-.2-.7-.6-.8C19.9 4.1 19 4 18 4c-1.9 0-3.6.5-5 1.4Z"/>`,
  search: `<path d="M10.5 3a7.5 7.5 0 0 1 5.9 12.1l4.3 4.3a1.1 1.1 0 0 1-1.6 1.6l-4.3-4.3A7.5 7.5 0 1 1 10.5 3Zm0 2.2a5.3 5.3 0 1 0 0 10.6 5.3 5.3 0 0 0 0-10.6Z"/>`,
  receipt: `<path d="M6 2.5c-.6 0-1 .4-1 1v17.1c0 .8.9 1.2 1.5.7l1.4-1.1 1.7 1.3c.4.3.9.3 1.3 0l1.6-1.3 1.6 1.3c.4.3.9.3 1.3 0l1.7-1.3 1.4 1.1c.6.5 1.5.1 1.5-.7V3.5c0-.6-.4-1-1-1H6Zm2.3 4.2h7.4a.9.9 0 0 1 0 1.8H8.3a.9.9 0 0 1 0-1.8Zm0 3.8h7.4a.9.9 0 0 1 0 1.8H8.3a.9.9 0 0 1 0-1.8Zm0 3.8h4.6a.9.9 0 0 1 0 1.8H8.3a.9.9 0 0 1 0-1.8Z"/>`,
  insights: `<path d="M20.1 5.2a2.1 2.1 0 0 0-2 2.8l-2.6 2.6a2.1 2.1 0 0 0-1.3 0l-1.9-1.9a2.1 2.1 0 1 0-4 .9L5.5 12.4a2.1 2.1 0 1 0 1.5 1.5l2.8-2.8a2.1 2.1 0 0 0 1.2 0l1.9 1.9a2.1 2.1 0 1 0 4-.9l2.6-2.6a2.1 2.1 0 1 0 .6-4.3ZM4 19.4h16a1.1 1.1 0 0 1 0 2.2H4a1.1 1.1 0 0 1 0-2.2Z"/>`,
  gamepad: `<path d="M17 6.5H7a5 5 0 0 0-5 5v1.2a4.3 4.3 0 0 0 7.7 2.6l.4-.5h3.8l.4.5A4.3 4.3 0 0 0 22 12.7v-1.2a5 5 0 0 0-5-5ZM8.4 12.6H7.6v.8a.9.9 0 0 1-1.8 0v-.8H5a.9.9 0 0 1 0-1.8h.8V10a.9.9 0 0 1 1.8 0v.8h.8a.9.9 0 0 1 0 1.8Zm6.4.9a1.1 1.1 0 1 1 0-2.3 1.1 1.1 0 0 1 0 2.3Zm2.6 2a1.1 1.1 0 1 1 0-2.3 1.1 1.1 0 0 1 0 2.3Zm0-4.1a1.1 1.1 0 1 1 0-2.3 1.1 1.1 0 0 1 0 2.3Zm2.6 2a1.1 1.1 0 1 1 0-2.3 1.1 1.1 0 0 1 0 2.3Z"/>`,
  trophy: `<path d="M17.5 4V3a1 1 0 0 0-1-1h-9a1 1 0 0 0-1 1v1H4.2a1 1 0 0 0-1 1v1.6a4.4 4.4 0 0 0 3.9 4.3 5.6 5.6 0 0 0 3.8 3v2.4H8.6a1.1 1.1 0 0 0 0 2.2h6.8a1.1 1.1 0 0 0 0-2.2h-2.3v-2.4a5.6 5.6 0 0 0 3.8-3 4.4 4.4 0 0 0 3.9-4.3V5a1 1 0 0 0-1-1h-2.3ZM6.5 9.2A2.6 2.6 0 0 1 5 6.6V6h1.5v3.2Zm12.5-2.6A2.6 2.6 0 0 1 17.5 9.2V6H19v.6ZM7.5 20.3h9a1.1 1.1 0 0 1 0 2.2h-9a1.1 1.1 0 0 1 0-2.2Z"/>`,
  leaderboard: `<path d="M4.5 12.8h3.3c.6 0 1 .4 1 1v6.4c0 .6-.4 1-1 1H4.5c-.6 0-1-.4-1-1v-6.4c0-.6.4-1 1-1Zm5.9-10h3.2c.6 0 1 .4 1 1v17.4c0 .6-.4 1-1 1h-3.2c-.6 0-1-.4-1-1V3.8c0-.6.4-1 1-1Zm5.8 6.1h3.3c.6 0 1 .4 1 1v11.3c0 .6-.4 1-1 1h-3.3c-.6 0-1-.4-1-1V9.9c0-.6.4-1 1-1Z"/>`,
  bookmark: `<path d="M7 2.5h10a2 2 0 0 1 2 2v16.1c0 .8-.9 1.3-1.5.8L12 17.3l-5.5 4.1c-.6.5-1.5 0-1.5-.8V4.5a2 2 0 0 1 2-2Z"/>`,
  bolt: `<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm.6 4.8v4h2.6c.5 0 .8.6.5 1l-4.2 6.1c-.4.5-1.2.2-1.2-.4v-4H7.8c-.5 0-.8-.6-.5-1l4.1-6.1c.4-.6 1.2-.3 1.2.4Z"/>`,
  school: `<path d="M11.4 2.3 1.9 7.1a.7.7 0 0 0 0 1.2l9.5 4.8c.4.2.8.2 1.2 0l9.5-4.8a.7.7 0 0 0 0-1.2l-9.5-4.8a1.3 1.3 0 0 0-1.2 0ZM5 11.4v3.9c0 .8.4 1.5 1.1 1.9l4.8 2.5c.7.4 1.5.4 2.2 0l4.8-2.5c.7-.4 1.1-1.1 1.1-1.9v-3.9l-5.4 2.8c-1 .5-2.2.5-3.2 0L5 11.4Zm15.9-1.6a.9.9 0 0 0-.9.9v6.4a.9.9 0 0 0 1.8 0v-6.4a.9.9 0 0 0-.9-.9Z"/>`,
  robot: `<path d="M13.1 2.6a1.1 1.1 0 0 0-2.2 0V5H7a3.5 3.5 0 0 0-3.5 3.5v9A3.5 3.5 0 0 0 7 21h10a3.5 3.5 0 0 0 3.5-3.5v-9A3.5 3.5 0 0 0 17 5h-3.9V2.6ZM9 10.5a1.6 1.6 0 1 1 0 3.2 1.6 1.6 0 0 1 0-3.2Zm6 0a1.6 1.6 0 1 1 0 3.2 1.6 1.6 0 0 1 0-3.2Zm-5.4 5.8h4.8a.9.9 0 0 1 0 1.8H9.6a.9.9 0 0 1 0-1.8Z"/>`,
  // interface
  menu: `<path d="M3.5 6.8h17a1 1 0 0 0 0-2h-17a1 1 0 0 0 0 2Zm0 6.2h17a1 1 0 0 0 0-2h-17a1 1 0 0 0 0 2Zm0 6.2h17a1 1 0 0 0 0-2h-17a1 1 0 0 0 0 2Z"/>`,
  bell: `<path d="M12 22a2.3 2.3 0 0 0 2.3-2.2H9.7A2.3 2.3 0 0 0 12 22Zm7-5.3-1.5-1.8v-4.1a5.6 5.6 0 0 0-4.3-5.5v-.6a1.2 1.2 0 0 0-2.4 0v.6A5.6 5.6 0 0 0 6.5 10.8v4.1L5 16.7c-.4.5 0 1.3.7 1.3h12.6c.7 0 1.1-.8.7-1.3Z"/>`,
  chev: `<path d="M9.3 6.3a1 1 0 0 0 0 1.4l4.3 4.3-4.3 4.3a1 1 0 1 0 1.4 1.4l5-5a1 1 0 0 0 0-1.4l-5-5a1 1 0 0 0-1.4 0Z"/>`,
  clock: `<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm.9 5.3v5.2l4.2 2.5a1 1 0 0 1-1 1.7l-4.6-2.8a1 1 0 0 1-.5-.9V7.3a1 1 0 0 1 2 0Z"/>`,
  check: `<path d="M9.3 16.2 5.1 12a1.1 1.1 0 1 0-1.6 1.6l5 5c.4.4 1.1.4 1.5 0L21.5 7.1a1.1 1.1 0 0 0-1.6-1.6L9.3 16.2Z"/>`,
  cross: `<path d="M18.3 5.7a1.1 1.1 0 0 0-1.6 0L12 10.4 7.3 5.7a1.1 1.1 0 0 0-1.6 1.6l4.7 4.7-4.7 4.7a1.1 1.1 0 1 0 1.6 1.6l4.7-4.7 4.7 4.7a1.1 1.1 0 0 0 1.6-1.6L13.6 12l4.7-4.7c.4-.4.4-1.1 0-1.6Z"/>`,
  down: `<path d="M12 3a1.1 1.1 0 0 1 1.1 1.1v9.3l3-3a1.1 1.1 0 0 1 1.6 1.5l-4.9 4.9c-.4.4-1.1.4-1.5 0l-4.9-4.9a1.1 1.1 0 1 1 1.6-1.5l3 3V4.1A1.1 1.1 0 0 1 12 3ZM4.5 18.8h15a1.1 1.1 0 0 1 0 2.2h-15a1.1 1.1 0 0 1 0-2.2Z"/>`,
  play: `<path d="M8.5 5.2c0-.8.9-1.3 1.6-.9l8.1 5.1c.6.4.6 1.3 0 1.7l-8.1 5.1c-.7.4-1.6-.1-1.6-.9V5.2Z"/>`,
  doc: `<path d="M13.4 2.6H7a2.5 2.5 0 0 0-2.5 2.5v13.8A2.5 2.5 0 0 0 7 21.4h10a2.5 2.5 0 0 0 2.5-2.5V8.7l-6.1-6.1Zm-.4 7V4.3l5.2 5.3h-5.2Z"/>`,
  flame: `<path d="M13.2 2.3c-.4-.4-1.1-.2-1.3.4-.5 1.7-1.6 3.1-3 4.4-1.8 1.7-3.4 3.6-3.4 6.4a7.5 7.5 0 0 0 15 0c0-3.3-1.9-5.6-3.6-7.4a16 16 0 0 1-3.7-3.8Zm-.1 16.6a3.1 3.1 0 0 1-3.1-3.1c0-1.4.8-2.3 1.7-3.2.5.6 1.1 1.1 1.8 1.7.8-.7 1.3-1.4 1.6-2.2.7.8 1.2 1.8 1.2 3a3.1 3.1 0 0 1-3.2 3.8Z"/>`,
  globe: `<path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm6.9 7h-2.6a14 14 0 0 0-1.3-4.1A8 8 0 0 1 18.9 9ZM12 4.1c.7 1 1.3 2.4 1.7 4.9h-3.4c.4-2.5 1-3.9 1.7-4.9ZM4.3 14a8 8 0 0 1 0-4h3a20 20 0 0 0 0 4h-3Zm.8 2h2.6c.3 1.5.7 2.9 1.3 4.1A8 8 0 0 1 5.1 16Zm2.6-7H5.1a8 8 0 0 1 3.9-4.1A14 14 0 0 0 7.7 9ZM12 19.9c-.7-1-1.3-2.4-1.7-4.9h3.4c-.4 2.5-1 3.9-1.7 4.9ZM14.1 13H9.9a18 18 0 0 1 0-4h4.2a18 18 0 0 1 0 4Zm.8 7.1c.6-1.2 1-2.6 1.3-4.1h2.6a8 8 0 0 1-3.9 4.1ZM16.7 14a20 20 0 0 0 0-4h3a8 8 0 0 1 0 4h-3Z"/>`,
  lock: `<path d="M17 9.2h-.9V7.3a4.1 4.1 0 1 0-8.2 0v1.9H7A2.1 2.1 0 0 0 4.9 11.3v8.1A2.1 2.1 0 0 0 7 21.5h10a2.1 2.1 0 0 0 2.1-2.1v-8.1A2.1 2.1 0 0 0 17 9.2Zm-7-1.9a2 2 0 1 1 4 0v1.9h-4V7.3Z"/>`,
  home: `<path d="M11.2 2.5a1.3 1.3 0 0 1 1.6 0l8 6.4c.3.2.5.6.5 1v10.2c0 .7-.6 1.3-1.3 1.3h-4.9c-.6 0-1-.4-1-1v-4.9c0-.6-.5-1.1-1.1-1.1h-2c-.6 0-1.1.5-1.1 1.1v4.9c0 .6-.4 1-1 1H4c-.7 0-1.3-.6-1.3-1.3V9.9c0-.4.2-.8.5-1l8-6.4Z"/>`,
  person: `<path d="M12 12.2a4.6 4.6 0 1 0 0-9.2 4.6 4.6 0 0 0 0 9.2Zm0 2c-3.7 0-8 1.9-8 4.4v1.3c0 .6.5 1.1 1.1 1.1h13.8c.6 0 1.1-.5 1.1-1.1v-1.3c0-2.5-4.3-4.4-8-4.4Z"/>`,
  grid4: `<path d="M4.6 3.4h4a1.2 1.2 0 0 1 1.2 1.2v4a1.2 1.2 0 0 1-1.2 1.2h-4A1.2 1.2 0 0 1 3.4 8.6v-4a1.2 1.2 0 0 1 1.2-1.2Zm10.8 0h4a1.2 1.2 0 0 1 1.2 1.2v4a1.2 1.2 0 0 1-1.2 1.2h-4a1.2 1.2 0 0 1-1.2-1.2v-4a1.2 1.2 0 0 1 1.2-1.2ZM4.6 14.2h4a1.2 1.2 0 0 1 1.2 1.2v4a1.2 1.2 0 0 1-1.2 1.2h-4a1.2 1.2 0 0 1-1.2-1.2v-4a1.2 1.2 0 0 1 1.2-1.2Zm10.8 0h4a1.2 1.2 0 0 1 1.2 1.2v4a1.2 1.2 0 0 1-1.2 1.2h-4a1.2 1.2 0 0 1-1.2-1.2v-4a1.2 1.2 0 0 1 1.2-1.2Z"/>`,
  speaker: `<path d="M12.5 3.6c0-.8-1-1.3-1.6-.7L6.6 7H4.1A1.6 1.6 0 0 0 2.5 8.6v6.8A1.6 1.6 0 0 0 4.1 17h2.5l4.3 4.1c.6.6 1.6.2 1.6-.7V3.6Zm3.2 3.6a1 1 0 0 1 1.4-.2 7 7 0 0 1 0 10 1 1 0 0 1-1.2-1.6 5 5 0 0 0 0-6.8 1 1 0 0 1-.2-1.4Z"/>`,
  shuffle: `<path d="M17.3 3.4a1 1 0 0 0-.7 1.7l.8.8h-1.9c-2 0-3.8 1-4.9 2.7l-2.4 3.8a3.8 3.8 0 0 1-3.2 1.7H3.4a1 1 0 0 0 0 2h1.6c2 0 3.8-1 4.9-2.7l2.4-3.8a3.8 3.8 0 0 1 3.2-1.7h1.9l-.8.8a1 1 0 0 0 1.4 1.4l2.5-2.5a1 1 0 0 0 0-1.4l-2.5-2.5a1 1 0 0 0-.7-.3ZM3.4 6.6a1 1 0 0 0 0 2h1.6c1 0 1.9.4 2.5 1.1l.3.4 1.2-1.9-.1-.1A5.8 5.8 0 0 0 5 6.6H3.4Zm12.9 7.1h-1.9c-1 0-1.9-.4-2.5-1.1l-.3-.4-1.2 1.9.1.1a5.8 5.8 0 0 0 3.9 1.5h1.9l-.8.8a1 1 0 0 0 1.4 1.4l2.5-2.5a1 1 0 0 0 0-1.4l-2.5-2.5a1 1 0 1 0-1.4 1.4l.8.8Z"/>`,
  cal: `<path d="M7.4 2.4a1 1 0 0 1 1 1v1h7.2v-1a1 1 0 1 1 2 0v1h.9a2.6 2.6 0 0 1 2.6 2.6v12a2.6 2.6 0 0 1-2.6 2.6H5.5A2.6 2.6 0 0 1 2.9 19V7a2.6 2.6 0 0 1 2.6-2.6h.9v-1a1 1 0 0 1 1-1ZM4.9 9.6V19c0 .3.3.6.6.6h13a.6.6 0 0 0 .6-.6V9.6H4.9Z"/>`,
  layers: `<path d="M11.4 2.6 2.6 7a.7.7 0 0 0 0 1.2l8.8 4.4c.4.2.8.2 1.2 0L21.4 8.2a.7.7 0 0 0 0-1.2l-8.8-4.4a1.3 1.3 0 0 0-1.2 0ZM4.1 11.2l-1.5.8a.7.7 0 0 0 0 1.2l8.8 4.4c.4.2.8.2 1.2 0l8.8-4.4a.7.7 0 0 0 0-1.2l-1.5-.8-6.7 3.4c-1 .5-2.2.5-3.2 0l-6.7-3.4Zm0 5-1.5.8a.7.7 0 0 0 0 1.2l8.8 4.4c.4.2.8.2 1.2 0l8.8-4.4a.7.7 0 0 0 0-1.2l-1.5-.8-6.7 3.4c-1 .5-2.2.5-3.2 0L4.1 16.2Z"/>`,
  bulb: `<path d="M12 2.2a7 7 0 0 0-4.2 12.6c.5.4.8 1 .8 1.6v.5c0 .7.6 1.3 1.3 1.3h4.2c.7 0 1.3-.6 1.3-1.3v-.5c0-.6.3-1.2.8-1.6A7 7 0 0 0 12 2.2ZM9.9 19.6h4.2a1 1 0 0 1 0 2H9.9a1 1 0 0 1 0-2Zm.6 2.7h3a1 1 0 0 1-1 .9h-1a1 1 0 0 1-1-.9Z"/>`,
  wifioff: `<path d="M3.2 2.3a1.1 1.1 0 0 0-1.5 1.5l3 3A14 14 0 0 0 1.4 8.6a1.1 1.1 0 1 0 1.4 1.7 11.6 11.6 0 0 1 2.6-1.6l2.2 2.2a8 8 0 0 0-2.3 1.5 1.1 1.1 0 1 0 1.5 1.6 5.9 5.9 0 0 1 2.6-1.4l2.4 2.4A3.6 3.6 0 0 0 9 16.1a1.1 1.1 0 1 0 1.6 1.5 1.9 1.9 0 0 1 2.9 0l.1.1 6.2 6.2a1.1 1.1 0 0 0 1.5-1.5L3.2 2.3Zm9.3 4.2c2.9 0 5.7 1 8 2.8a1.1 1.1 0 0 0 1.4-1.7A15.2 15.2 0 0 0 9.4 4.5l2.1 2.1h1Z"/>`,
};

export const icon = (name, size, color) =>
  `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="${color}" aria-hidden="true">${I[name]}</svg>`;

/* The phone. A dark titanium frame, a punch-hole camera, a real shadow.
   The screen is 408 CSS px wide at 19.5:9, the common modern Android ratio. */
export const SCREEN_W = 408;
export const SCREEN_H = 884;

export const phone = (inner) => `
<div class="device">
  <div class="screen">
    ${inner}
    <div class="punch"></div>
  </div>
</div>`;

export const statusbar = (dark = false) => {
  const c = dark ? '#FFFFFF' : C.t1;
  return `
  <div class="sbar" style="color:${c}">
    <div class="sb-time">9:41</div>
    <div class="sb-right">
      <svg width="17" height="12" viewBox="0 0 17 12" fill="${c}"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="4.5" y="5.5" width="3" height="6.5" rx="1"/><rect x="9" y="3" width="3" height="9" rx="1"/><rect x="13.5" y="0" width="3" height="12" rx="1"/></svg>
      <svg width="16" height="12" viewBox="0 0 16 12" fill="${c}"><path d="M8 11.2 1.2 4.4a9.6 9.6 0 0 1 13.6 0L8 11.2Z"/></svg>
      <svg width="25" height="12" viewBox="0 0 25 12" fill="none"><rect x=".6" y=".6" width="21" height="10.8" rx="3" stroke="${c}" stroke-opacity=".45" stroke-width="1.1"/><rect x="2.2" y="2.2" width="15" height="7.6" rx="1.8" fill="${c}"/><path d="M23.2 4.2v3.6a2 2 0 0 0 0-3.6Z" fill="${c}" fill-opacity=".45"/></svg>
    </div>
  </div>`;
};

/* One finished Play asset: hue wash, headline, device. */
export const page = ({ grad, headline, sub, inner, light = false }) => `<!doctype html>
<html><head><meta charset="utf-8">
<style>
  @font-face{font-family:SG;src:url(assets/SpaceGrotesk-Bold.ttf);font-weight:700}
  @font-face{font-family:SG;src:url(assets/SpaceGrotesk-SemiBold.ttf);font-weight:600}
  @font-face{font-family:SG;src:url(assets/SpaceGrotesk-Medium.ttf);font-weight:500}
  @font-face{font-family:IN;src:url(assets/Inter-Bold.ttf);font-weight:700}
  @font-face{font-family:IN;src:url(assets/Inter-SemiBold.ttf);font-weight:600}
  @font-face{font-family:IN;src:url(assets/Inter-Medium.ttf);font-weight:500}
  @font-face{font-family:IN;src:url(assets/Inter-Regular.ttf);font-weight:400}
  @font-face{font-family:JB;src:url(assets/JetBrainsMono-Bold.ttf);font-weight:700}
  *{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}
  body{width:720px;height:1280px;overflow:hidden;font-family:IN,sans-serif;
       background:${grad};position:relative}
  .vig{position:absolute;inset:0;background:
       radial-gradient(120% 70% at 50% 0%, rgba(255,255,255,.20), transparent 60%),
       radial-gradient(90% 50% at 50% 100%, rgba(0,0,0,.22), transparent 60%)}
  .cap{position:absolute;top:74px;left:0;right:0;padding:0 62px;text-align:center;z-index:3}
  .cap h1{font-family:SG;font-weight:700;font-size:52px;line-height:1.1;letter-spacing:-1.4px;
          color:${light ? '#0B1020' : '#fff'};text-shadow:${light ? 'none' : '0 2px 18px rgba(0,0,0,.18)'}}
  .cap p{margin-top:18px;font-size:22px;line-height:1.42;font-weight:500;
         color:${light ? 'rgba(11,16,32,.66)' : 'rgba(255,255,255,.82)'}}
  .stage{position:absolute;top:338px;left:0;right:0;display:flex;justify-content:center;z-index:2}
  .device{width:${SCREEN_W + 22}px;height:${SCREEN_H + 22}px;border-radius:54px;padding:11px;
     background:linear-gradient(160deg,#3A3F4B 0%,#1B1E25 38%,#0E1014 70%,#2B303A 100%);
     box-shadow:0 2px 0 rgba(255,255,255,.18) inset, 0 50px 90px rgba(0,0,0,.42),
                0 18px 36px rgba(0,0,0,.30), 0 0 0 1px rgba(0,0,0,.35)}
  .screen{width:${SCREEN_W}px;height:${SCREEN_H}px;border-radius:44px;overflow:hidden;
     background:${C.bg};position:relative;color:${C.t1}}
  .punch{position:absolute;top:15px;left:50%;transform:translateX(-50%);
     width:11px;height:11px;border-radius:50%;background:#05070A;
     box-shadow:0 0 0 1.5px rgba(255,255,255,.06)}
  .sbar{position:absolute;top:0;left:0;right:0;height:46px;display:flex;align-items:center;
     justify-content:space-between;padding:0 24px;font-size:13.5px;font-weight:600;z-index:5}
  .sb-right{display:flex;align-items:center;gap:5px}
  .body{position:absolute;top:46px;left:0;right:0;bottom:0;overflow:hidden}
</style></head>
<body>
  <div class="vig"></div>
  <div class="cap"><h1>${headline}</h1><p>${sub}</p></div>
  <div class="stage">${phone(inner)}</div>
</body></html>`;
