/* =============================================================================
 * A STAND-IN BACKEND FOR THE OFFLINE VAULT TEST.
 *
 * WHY THIS EXISTS AND WHAT IT IS NOT.
 * The offline vault's promise — "no internet is not an answer for a question
 * the phone is already holding" — can only be proved by a REAL round trip
 * followed by a REAL network failure. A mocked Api class proves the repository
 * calls the right methods; it does not prove that Dio, the JSON decoding, the
 * Drift schema, the sqlite file on disk and the scoring all survive the
 * network going away, because none of those are exercised.
 *
 * So this serves the actual `/api/mobile/pack` and `/api/mobile/results/offline`
 * contracts over real HTTP on 127.0.0.1, and the integration test points the
 * real app at it with --dart-define=LIP_API. The app's own Api client, its own
 * database and its own scoring do all the work. Then the test KILLS this
 * server, and everything the vault promises has to keep working against a
 * connection that genuinely refuses.
 *
 * It is a test fixture. It is never shipped, never imported by the app, and
 * holds no logic the app depends on — the shapes below are copied from the
 * real routes so a drift between them shows up as a failing test.
 * ========================================================================== */
const http = require("http");

const PORT = parseInt(process.argv[2] || "4599", 10);

/* Twelve questions with a known answer key, so the test can assert an exact
   score rather than "some number came back". Two carry a passage, because an
   English pack that loses its comprehension body is unreadable offline and
   that is exactly the kind of thing a mock never catches. */
const LETTERS = ["A", "B", "C", "D"];
const questions = Array.from({ length: 12 }, (_, i) => ({
  id: `q-${i + 1}`,
  question: `Offline question ${i + 1}: which option is correct?`,
  options: ["first", "second", "third", "fourth"],
  letters: LETTERS,
  passage_id: i < 2 ? "p-1" : null,
  section: i < 2 ? "Comprehension" : null,
  year: 2019 + (i % 3),
  // Answer cycles A,B,C,D so a test that always picks A cannot pass by luck.
  answer: LETTERS[i % 4],
  explanation: `Because option ${LETTERS[i % 4]} follows from the definition.`,
  media: null,
}));

const received = [];

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const json = (code, body) => {
    res.writeHead(code, { "Content-Type": "application/json" });
    res.end(JSON.stringify(body));
  };

  if (url.pathname === "/api/mobile/pack") {
    return json(200, {
      ok: true,
      pack: {
        subjectId: url.searchParams.get("subject") || "sub-chem",
        subjectName: "Chemistry",
        examId: "exam-jamb",
        examSlug: "jamb",
        examShort: "JAMB",
        count: questions.length,
        builtAt: new Date().toISOString(),
      },
      questions,
      passages: [
        { id: "p-1", title: "A short passage", body: "The body a student must still be able to read with no signal." },
      ],
    });
  }

  if (url.pathname === "/api/mobile/results/offline" && req.method === "POST") {
    let raw = "";
    req.on("data", (c) => (raw += c));
    return req.on("end", () => {
      try {
        received.push(JSON.parse(raw));
      } catch {}
      json(200, { ok: true, message: "Result recorded." });
    });
  }

  // Anything the test did not teach this server about is a 404 with the same
  // envelope shape the real backend uses, so the app's error path is real too.
  return json(404, { ok: false, message: "No such route on the stand-in." });
});

server.listen(PORT, "127.0.0.1", () => {
  process.stdout.write(`stand-in backend listening on ${PORT}\n`);
});

/* The test asks for this on the way out, to confirm the queued result really
   arrived rather than merely being marked sent on the phone. */
process.on("SIGTERM", () => {
  process.stdout.write(`RESULTS_RECEIVED=${received.length}\n`);
  process.exit(0);
});
