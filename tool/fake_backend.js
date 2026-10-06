/* =============================================================================
 * A STAND-IN LOCKINPOINT, FOR DRIVING THE REAL APP.
 *
 * WHY THIS EXISTS AND WHAT IT IS NOT.
 * The founder installed a build where menus did not open, buttons did nothing
 * and JAMB led nowhere — none of which a unit test or an analyzer can see,
 * because every one of them is about what happens when a finger lands on a
 * widget. Proving those repairs needs the REAL app, running, with a student
 * tapping through it.
 *
 * That needs a server. Production cannot be it: there is no test account here,
 * and creating one would write to the live database. So this serves the real
 * contracts — the same routes, the same JSON shapes, copied from the route
 * files — over real HTTP on 127.0.0.1, and the app is pointed at it with
 * --dart-define=LIP_API.
 *
 * It is a test fixture. Never shipped, never imported by the app, and holding
 * no logic the app depends on: the shapes below are copies, so a drift between
 * them and the real routes shows up as a failing drive.
 * ========================================================================== */
const http = require("http");

const PORT = parseInt(process.argv[2] || "4599", 10);
const LETTERS = ["A", "B", "C", "D"];

// ---------------------------------------------------------------- fixtures --
const SUBJECTS = [
  { id: "eng", name: "Use of English", compulsory: true, stream: "general" },
  { id: "mth", name: "Mathematics", compulsory: false, stream: "science" },
  { id: "phy", name: "Physics", compulsory: false, stream: "science" },
  { id: "chm", name: "Chemistry", compulsory: false, stream: "science" },
  { id: "bio", name: "Biology", compulsory: false, stream: "science" },
];

const question = (i, subjectId) => ({
  id: `q-${subjectId}-${i}`,
  subject_id: subjectId,
  question: `Question ${i} for ${subjectId}: which option is correct?`,
  options: ["first option", "second option", "third option", "fourth option"],
  letters: LETTERS,
  answer: LETTERS[i % 4],
  explanation: `Option ${LETTERS[i % 4]} follows from the definition.`,
  year: 2019 + (i % 3),
  passage_id: null,
  section: null,
});

const pack = (subjectId, n) =>
  Array.from({ length: n }, (_, i) => question(i + 1, subjectId));

/* Attempts live for the life of the process, so submit and review really do
   read back what start wrote — the drive asserts on that. */
const attempts = new Map();
let attemptSeq = 0;
const saved = new Set();

const json = (res, code, body) => {
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
};

const readBody = (req) =>
  new Promise((resolve) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      try {
        resolve(JSON.parse(raw || "{}"));
      } catch {
        resolve({});
      }
    });
  });

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const p = url.pathname;
  const body = req.method === "POST" ? await readBody(req) : {};

  // ------------------------------------------------------------- identity --
  if (p === "/api/mobile/ping") return json(res, 200, { ok: true });

  if (p === "/api/auth/login")
    return json(res, 200, {
      ok: true,
      // The REAL key names the app reads. Getting these wrong is exactly the
      // contract drift this drive exists to catch.
      access_token: "test-access",
      refresh_token: "test-refresh",
      name: "Ada",
      user: { id: "stu-1", email: "ada@example.com" },
    });

  if (p === "/api/auth/refresh")
    return json(res, 200, { ok: true, access_token: "test-access", refresh_token: "test-refresh" });

  if (p === "/api/auth/logout") return json(res, 200, { ok: true });

  if (p === "/api/mobile/dashboard")
    return json(res, 200, {
      ok: true,
      student: {
        name: "Ada",
        surname: "Obi",
        email: "ada@example.com",
        username: "ada",
        activated: true,
        // The real dashboard sends this; the drive needs a verified student
        // so the verify banner is not sitting over the home grid.
        emailVerified: true,
        streak: 4,
        productKey: "LIP-7K2M-9QRT",
        referralCode: "ADA123",
        state: "Lagos",
        countryCode: "NG",
        institution: "",
        subjectCombination: "",
      },
      counts: { questions: 41230, attempts: 12, notes: 88 },
      resume: null,
    });

  if (p === "/api/profile/complete") {
    // GET answers with THIS student's country's divisions; POST saves one.
    // The stand-in mirrors both, because the app's state picker reads the
    // list from here rather than carrying its own copy of Nigeria's 37.
    if (req.method === "GET")
      return json(res, 200, {
        ok: true,
        complete: true,
        missing: [],
        country_code: "NG",
        states: ["Abia", "Lagos", "Kano", "Oyo", "Rivers", "FCT"],
      });
    return json(res, 200, { ok: true, complete: true });
  }

  if (p === "/api/auth/verify") {
    const code = String(body.code || "");
    return code === "123456"
      ? json(res, 200, { ok: true })
      : json(res, 200, { ok: false, message: "That code is not correct. Check your email and try again." });
  }

  if (p === "/api/me")
    return json(res, 200, { ok: true, message: "Saved." });

  // ------------------------------------------------------------- practice --
  if (p === "/api/public/exam-tree") {
    /* THE REAL ROUTE HAS THREE BRANCHES, and this stand-in had one.
       `?subjects=<slug>` answers with that exam's subject list; without it the
       app's subject list came back empty, and the UTME combination step —
       which needs to find Use of English in that list — showed its "the JAMB
       bank has no English subject" empty state. A stand-in that answers a
       question the real server answers differently tests nothing. */
    const forExam = url.searchParams.get("subjects");
    if (forExam) return json(res, 200, { ok: true, subjects: SUBJECTS });

    const chooserId = url.searchParams.get("chooser");
    if (chooserId) {
      const subj = SUBJECTS.find((s) => s.id === chooserId) || { id: chooserId, name: chooserId };
      return json(res, 200, {
        ok: true,
        subject: { id: subj.id, name: subj.name },
        exam: { slug: "waec", short_name: "WAEC", has_gce_series: true },
        years: [{ year: 2023, n: 40 }, { year: 2022, n: 40 }],
        topics: [{ topic_id: "t1", name: "Algebra", n: 20, n_tutorial: 4 }],
        past: 80,
        tutorial: 12,
      });
    }

    return json(res, 200, {
      ok: true,
      exams: [
        { id: "e-jamb", slug: "jamb", short_name: "JAMB", full_name: "Unified Tertiary Matriculation Examination", is_jamb: true, subjects: SUBJECTS },
        { id: "e-waec", slug: "waec", short_name: "WAEC", full_name: "West African Senior School Certificate", is_jamb: false, subjects: SUBJECTS },
        { id: "e-gce", slug: "waec-gce", short_name: "WAEC GCE", full_name: "WAEC General Certificate (private)", is_jamb: false, subjects: SUBJECTS },
      ],
    });
  }

  if (p === "/api/attempts") {
    if (body.action === "start") {
      const id = `att-${++attemptSeq}`;
      const ids = Array.isArray(body.subjectIds) && body.subjectIds.length
        ? body.subjectIds
        : ["mth"];
      /* THE MINI MOCK HONOURS `per`, AS THE REAL ROUTE DOES.
         /api/attempts reads `parseInt(body.per) || 10` for a jamb_mini. The
         full mock's real shape is 60 English + 40 each, shrunk to 5 here so a
         drive is not a two-hour paper — the SHAPE is what matters, and the
         mini's shape is "exactly what the student asked for". */
      const per =
        body.mode === "jamb_mock" ? 5
        : body.mode === "jamb_mini" ? (parseInt(body.per, 10) || 10)
        : 4;
      const qs = body.fromSaved
        ? [...saved].map((sid, i) => question(i + 1, "mth"))
        : ids.flatMap((s) => pack(s, per));
      const subjects = body.fromSaved
        ? [{ id: "saved", name: "Saved questions" }]
        : ids.map((s) => SUBJECTS.find((x) => x.id === s) || { id: s, name: s });
      attempts.set(id, { qs, mode: body.mode || "practice" });
      return json(res, 200, {
        ok: true,
        attemptId: id,
        mode: body.mode || "practice",
        duration: body.mode === "cbt" || String(body.mode).startsWith("jamb") ? 1800 : 0,
        // Practice ships the key; CBT and mocks do not, exactly like the real route.
        questions: qs.map((q) =>
          (body.mode || "practice") === "practice"
            ? q
            : { ...q, answer: undefined, explanation: undefined },
        ),
        passages: {},
        subjects: subjects.map((s) => ({ id: s.id, name: s.name })),
      });
    }
    if (body.action === "progress") return json(res, 200, { ok: true });
    if (body.action === "submit" || body.action === "review") {
      const a = attempts.get(body.attemptId);
      if (!a) return json(res, 200, { ok: false, message: "We could not find that attempt." });
      const answers = body.answers || {};
      let correct = 0;
      const corrections = a.qs.map((q) => {
        const chosen = (answers[q.id] || "").toUpperCase();
        const isRight = chosen === q.answer;
        if (isRight) correct++;
        return { id: q.id, question: q.question, options: q.options, chosen, right: q.answer, isRight, explanation: q.explanation };
      });
      const isJamb = a.mode.startsWith("jamb");
      const total = a.qs.length;
      const overall = isJamb
        ? Math.round((correct / Math.max(total, 1)) * 400)
        : Math.round((correct / Math.max(total, 1)) * 100);
      return json(res, 200, {
        ok: true,
        score: { correct, total, overall, isJamb, perSubject: [], scaled: [] },
        corrections,
      });
    }
    return json(res, 200, { ok: false, message: "Unknown action." });
  }

  if (p === "/api/mobile/pack")
    return json(res, 200, {
      ok: true,
      pack: {
        subjectId: url.searchParams.get("subject") || "chm",
        subjectName: "Chemistry",
        examId: "e-jamb",
        examSlug: "jamb",
        examShort: "JAMB",
        count: 12,
        builtAt: new Date().toISOString(),
      },
      /* THE PACK CARRIES ITS COMPREHENSION PASSAGE.
         The real route selects every passage the pack's questions point at —
         "or an English pack is unreadable", as it says. A stand-in that sends
         an empty list lets a vault that drops passages look healthy. */
      questions: pack("chm", 12).map((q, i) =>
        i === 0 ? { ...q, passage_id: "p-1", passage_order: 1 } : q,
      ),
      passages: [
        {
          id: "p-1",
          title: "A short passage",
          body: "Read this on a bus with no signal and answer what follows.",
        },
      ],
    });

  if (p === "/api/mobile/results/offline") return json(res, 200, { ok: true });

  if (p === "/api/qmark") {
    if (body.op === "save") { saved.add(body.questionId); return json(res, 200, { ok: true, message: "Saved to your list." }); }
    if (body.op === "unsave") { saved.delete(body.questionId); return json(res, 200, { ok: true, message: "Removed." }); }
    if (body.op === "saved_ids") return json(res, 200, { ok: true, ids: [...saved] });
    return json(res, 200, { ok: false });
  }

  if (p === "/api/mobile/saved")
    return json(res, 200, {
      ok: true,
      total: saved.size,
      page: 1,
      per: 20,
      questions: [...saved].map((id, i) => ({
        id,
        question: `A question you saved (${i + 1})`,
        options: ["a", "b", "c", "d"],
        answer: "B",
        explanation: "Because.",
        subject: "Mathematics",
        year: 2021,
      })),
    });

  // ---------------------------------------------------------------- games --
  if (p === "/api/games/pool")
    return json(res, 200, {
      ok: true,
      questions: pack("mth", parseInt(url.searchParams.get("count") || "15", 10)),
    });

  if (p === "/api/games/ladder") {
    const state = (rung, status = "playing") => ({
      id: "climb-1",
      rung,
      total: 15,
      ladder: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150],
      firstNet: 5,
      secondNet: null,
      banked: 0,
      status,
      score: (rung - 1) * 10,
      lifelines: { fifty: true, class: true, lumi: true },
      seconds: null,
      question: { id: `q-climb-${rung}`, question: `Climb question ${rung}`, options: LETTERS.map((L) => ({ letter: L, text: `option ${L}` })) },
    });
    if (body.op === "start") return json(res, 200, { ok: true, state: state(1) });
    if (body.op === "state") return json(res, 200, { ok: true, state: state(1) });
    if (body.op === "lifeline") {
      if (body.which === "class")
        // The REAL key the route sends. The app read `distribution` and got nothing.
        return json(res, 200, { ok: true, classVote: { percentages: { A: 61, B: 21, C: 12, D: 6 }, real: true, sample: 240 }, state: state(1) });
      return json(res, 200, { ok: true, state: state(1) });
    }
    if (body.op === "answer") {
      const right = body.letter === "A";
      return json(res, 200, {
        ok: true,
        correct: right,
        won: false,
        right: right ? null : "A",
        explanation: "A is right because of the definition.",
        state: state(right ? 2 : 1, right ? "playing" : "lost"),
      });
    }
    if (body.op === "walk") return json(res, 200, { ok: true, state: state(1, "walked") });
    return json(res, 200, { ok: false, message: "Unknown move." });
  }

  // -------------------------------------------------------------- content --
  if (p === "/api/mobile/classroom") {
    if (url.searchParams.get("note"))
      return json(res, 200, { ok: true, note: { id: "n1", title: "Moles", body: "<p>A mole is 6.022e23 particles.</p>", kind: "note" } });
    if (url.searchParams.get("subject"))
      return json(res, 200, {
        ok: true,
        notes: [{ id: "n1", title: "The mole concept", kind: "note" }],
        videos: [{ id: "v1", title: "Titration, explained", url: "https://youtu.be/x" }],
        documents: [{ id: "d1", title: "Past questions PDF", url: "https://example.com/x.pdf" }],
      });
    if (url.searchParams.get("exam"))
      return json(res, 200, { ok: true, subjects: SUBJECTS.map((s) => ({ id: s.id, name: s.name })) });
    return json(res, 200, { ok: true, exams: [{ slug: "jamb", name: "JAMB" }, { slug: "waec", name: "WAEC" }] });
  }

  if (p === "/api/mobile/career") {
    if (url.searchParams.get("course"))
      return json(res, 200, { ok: true, offers: [{ departmentId: "d1", course: "Medicine and Surgery", cutoff: "78 - 85", note: "Merit list from the aggregate.", institution: "University of Ibadan", shortName: "UI", slug: "ui", type: "university", state: "Oyo" }] });
    if (url.searchParams.get("inst"))
      return json(res, 200, { ok: true, institution: { id: "i1", name: "University of Ibadan", shortName: "UI", type: "university", ownership: "federal", state: "Oyo", about: "", aggregate: "<p>(UTME / 8) + (Post UTME / 2)</p>" }, departments: [{ id: "d1", name: "Medicine and Surgery", cutoff: "78 - 85", note: "" }] });
    if (url.searchParams.get("career"))
      return json(res, 200, { ok: true, career: { name: "Medicine", slug: "medicine", summary: "Care for the sick.", body: "<p>Long training, deep reward.</p>", stream: "science", icon: "", courses: [{ name: "Medicine and Surgery", note: "" }] } });
    return json(res, 200, {
      ok: true,
      careers: [{ name: "Medicine", slug: "medicine", summary: "Care for the sick.", stream: "science", icon: "" }],
      institutions: [{ id: "i1", name: "University of Ibadan", shortName: "UI", slug: "ui", type: "university", state: "Oyo" }],
    });
  }

  if (p === "/api/search")
    return json(res, 200, {
      ok: true,
      total: 2,
      rows: [
        { id: "s1", question: "What is 2 + 2?", options: ["3", "4", "5", "6"], answer: "B", explanation: "Addition.", subject: "Mathematics", exam: "JAMB", year: 2020 },
        { id: "s2", question: "Define a mole.", options: ["a", "b", "c", "d"], answer: "A", explanation: "Avogadro.", subject: "Chemistry", exam: "JAMB", year: 2021 },
      ],
    });

  if (p === "/api/leaderboard")
    return json(res, 200, {
      ok: true,
      rows: [
        { rank: 1, name: "Chidi", username: "chidi", points: 980, country: "NG", state: "Lagos", institution: "UI" },
        { rank: 2, name: "Ada", username: "ada", points: 940, country: "NG", state: "Lagos", institution: "UI" },
      ],
      me: { rank: 2, points: 940 },
    });

  if (p === "/api/mobile/rounds")
    return json(res, 200, {
      ok: true,
      round: { name: "August Sprint", slug: "aug", description: "Two weeks, real prizes.", startsAt: new Date(Date.now() - 86400000).toISOString(), endsAt: new Date(Date.now() + 5 * 86400000).toISOString(), countryCode: "NG", prizes: [{ position: 1, prize: "N20,000", note: "" }] },
      winners: [],
    });

  if (p === "/api/mobile/topics")
    return json(res, 200, { ok: true, minSeen: 6, weakest: [{ topicId: "t1", topic: "Mole Concept", subject: "Chemistry", seen: 18, correct: 4, percent: 22.2 }], strongest: [], rows: [{ topicId: "t1", topic: "Mole Concept", subject: "Chemistry", seen: 18, correct: 4, percent: 22.2 }], unproven: [] });

  if (p === "/api/mobile/plan") {
    if (req.method === "POST") return json(res, 200, { ok: true, message: "A 14 day plan built from your weakest topics." });
    return json(res, 200, { ok: true, plan: null, items: [] });
  }

  if (p === "/api/mobile/results")
    return json(res, 200, {
      ok: true,
      summary: { sittings: 2, questions: 40, correct: 28, accuracy: 70, minutes: 45, weakest: "Chemistry", strongest: "Mathematics" },
      attempts: [{ id: "att-old", mode: "practice", takenAt: new Date().toISOString(), durationSeconds: 900, correct: 14, total: 20, percent: 70, overall: 70, isJamb: false, perSubject: [] }],
      subjects: [{ name: "Mathematics", correct: 16, total: 20, sittings: 1, percent: 80 }],
      insight: "Your Chemistry is where the marks are going.",
    });

  if (p === "/api/mobile/activation")
    return json(res, 200, {
      ok: true,
      activated: false,
      productKey: "LIP-7K2M-9QRT",
      price: { amount: 5000, currency: "NGN", note: "One payment opens everything." },
      accounts: [{ id: "b1", bankName: "Moniepoint", accountName: "LockInPoint Ltd", accountNumber: "8012345678", currency: "NGN", instructions: "Use your username as the narration." }],
      methods: { card: true, transfer: true, key: true },
    });

  if (p === "/api/activate/key")
    return json(res, 200, { ok: true, message: "Activated! Everything is open." });

  if (p === "/api/pay/init")
    return json(res, 200, { ok: true, url: "https://checkout.paystack.com/test" });

  if (p === "/api/ai/ask")
    return json(res, 200, { ok: true, answer: "Start from the definition of a mole, then divide by molar mass." });

  // ----------------------------------------------------- admin-owned bits --
  if (p === "/api/public/contacts")
    return json(res, 200, { ok: true, contacts: [{ kind: "whatsapp", label: "WhatsApp us", value: "+2348012345678", description: "" }] });
  if (p === "/api/public/quote") return json(res, 200, { ok: true, quote: { text: "Lock in.", author: "Bello" } });
  if (p === "/api/public/price") return json(res, 200, { ok: true, amount: 5000, currency: "NGN" });
  if (p === "/api/public/carousel") return json(res, 200, { ok: true, slides: [] });
  if (p === "/api/public/tiles") return json(res, 200, { ok: true, tiles: [] });
  if (p === "/api/notices/pending") return json(res, 200, { ok: true, items: [] });
  if (p === "/api/announcements") return json(res, 200, { ok: true, items: [] });

  return json(res, 404, { ok: false, message: `No such route on the stand-in: ${p}` });
});

server.listen(PORT, "127.0.0.1", () => {
  process.stdout.write(`stand-in LockInPoint listening on ${PORT}\n`);
});
