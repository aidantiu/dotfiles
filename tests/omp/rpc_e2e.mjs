// Usage: node rpc_e2e.mjs <model> <answers-csv: yes|no per confirm> <steps...> [--no-ui]
// Steps: plain text = prompt; "/model p/id" = set_model; "/new" = new_session; "/btw q" = side question;
//        "/compact" = compact; "/steer t" / "/follow_up t" = queue a message; "/sleep N" = wait N seconds.
// Prints {"confirms":N,"titles":[...],"results":[...],"trace":[...],"finalModel":"provider/id"}.
// With REQ_LOG=<fake provider log>, every trace entry carries the number of fable requests seen so far.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import readline from "node:readline";
const args = process.argv.slice(2);
const noUi = args.includes("--no-ui");
const [model, answersCsv, ...steps] = args.filter((a) => a !== "--no-ui");
const answers = answersCsv ? answersCsv.split(",") : [];
const child = spawn("omp", ["--mode", "rpc", ...(noUi ? ["--no-ui"] : []), "--model", model, "--no-session"], { stdio: ["pipe", "pipe", "inherit"] });
const send = (o) => child.stdin.write(JSON.stringify(o) + "\n");
const out = { confirms: 0, titles: [], results: [], trace: [], finalModel: null };
const fables = () => { try { return readFileSync(process.env.REQ_LOG, "utf8").split("\n").filter((l) => l.includes("fable")).length; } catch { return 0; } };
const trace = (s) => out.trace.push(process.env.REQ_LOG ? `${s} [fable=${fables()}]` : s);
let pending = null, n = 0;
const finish = (code, extra = {}) => { clearTimeout(timer); console.log(JSON.stringify({ ...out, ...extra })); child.kill(); process.exit(code); };
const done = (result) => { out.results.push(result); trace(`${steps[n - 1]} -> ${result}`); pending = null; next(); };
const next = () => {
  if (n >= steps.length) { pending = "state"; send({ id: "state", type: "get_state" }); return; }
  const id = `p${n}`, text = steps[n++]; pending = id;
  let m;
  if (text === "/new") send({ id, type: "new_session" });
  else if ((m = /^\/model\s+([^/\s]+)\/(\S+)$/.exec(text))) send({ id, type: "set_model", provider: m[1], modelId: m[2] }); // "/model x/y" opens a TUI picker
  else if ((m = /^\/btw\s+(.+)$/.exec(text))) send({ id, type: "btw", question: m[1] });
  else if (text === "/compact") send({ id, type: "compact" });
  else if ((m = /^\/(steer|follow_up)\s+(.+)$/.exec(text))) send({ id, type: m[1], message: m[2] });
  else if ((m = /^\/sleep\s+(\d+)$/.exec(text))) setTimeout(() => done("slept"), Number(m[1]) * 1000);
  else send({ id, type: "prompt", message: text });
};
readline.createInterface({ input: child.stdout }).on("line", (line) => {
  let msg; try { msg = JSON.parse(line); } catch { return; }
  if (msg.type === "ready") { next(); return; }
  if (msg.type === "extension_ui_request" && msg.method === "confirm") {
    out.confirms++; out.titles.push(`${msg.title} ${msg.message ?? ""}`);
    const yes = (answers.shift() ?? "no") === "yes";
    trace(`confirm -> ${yes ? "yes" : "no"}`);
    send({ type: "extension_ui_response", id: msg.id, confirmed: yes });
  } else if (msg.type === "extension_ui_request" && msg.method === "notify") {
    trace(`notify: ${msg.message}`);
  } else if (msg.type === "prompt_result" && msg.id === pending) {
    done(msg.status ?? "local");
  } else if (msg.type === "response" && msg.id === "state" && pending === "state") {
    const m = msg.data?.model; out.finalModel = m ? `${m.provider}/${m.id}` : null;
    finish(0);
  } else if (msg.type === "response" && msg.id === pending) {
    if (msg.command === "prompt" && msg.success && msg.data?.agentInvoked !== false) return; // wait for prompt_result
    if (msg.command === "btw" && msg.success) { setTimeout(() => done(`btw:${msg.data?.record?.status ?? "?"}`), 1500); return; }
    done(msg.success ? (msg.command === "prompt" ? "local" : "ok") : `error:${msg.error}`);
  }
});
const timer = setTimeout(() => finish(1, { timeout: true }), 90000);
child.on("exit", () => finish(1, { exited: true }));
