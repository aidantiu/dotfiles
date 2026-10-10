// Usage: node rpc_e2e.mjs <model> <answers-csv: yes|no per confirm> <prompts...> [--no-ui]
// Prints {"confirms":N,"titles":[...],"results":[...],"finalModel":"provider/id"}
import { spawn } from "node:child_process";
import readline from "node:readline";
const args = process.argv.slice(2);
const noUi = args.includes("--no-ui");
const [model, answersCsv, ...prompts] = args.filter((a) => a !== "--no-ui");
const answers = answersCsv ? answersCsv.split(",") : [];
const child = spawn("omp", ["--mode", "rpc", ...(noUi ? ["--no-ui"] : []), "--model", model, "--no-session"], { stdio: ["pipe", "pipe", "inherit"] });
const send = (o) => child.stdin.write(JSON.stringify(o) + "\n");
const out = { confirms: 0, titles: [], results: [], finalModel: null };
let pending = null, n = 0;
const next = () => {
  if (n < prompts.length) {
    const id = `p${n}`, text = prompts[n++]; pending = id;
    const m = /^\/model\s+([^/\s]+)\/(\S+)$/.exec(text);
    // "/model x/y" opens a TUI picker, so over RPC it is sent as a set_model command.
    if (m) send({ id, type: "set_model", provider: m[1], modelId: m[2] });
    else send({ id, type: "prompt", message: text });
  } else send({ id: "state", type: "get_state" });
};
readline.createInterface({ input: child.stdout }).on("line", (line) => {
  let msg; try { msg = JSON.parse(line); } catch { return; }
  if (msg.type === "ready") { next(); return; }
  if (msg.type === "extension_ui_request" && msg.method === "confirm") {
    out.confirms++; out.titles.push(`${msg.title} ${msg.message ?? ""}`);
    send({ type: "extension_ui_response", id: msg.id, confirmed: (answers.shift() ?? "no") === "yes" });
  } else if (msg.type === "prompt_result" && msg.id === pending) {
    out.results.push(msg.status ?? "local"); pending = null; next();
  } else if (msg.type === "response" && msg.id === pending && msg.command === "prompt" && msg.success && msg.data?.agentInvoked === false) {
    out.results.push("local"); pending = null; next();
  } else if (msg.type === "response" && msg.id === pending && msg.command === "set_model") {
    out.results.push(msg.success ? "model_set" : `error:${msg.error}`); pending = null; next();
  } else if (msg.type === "response" && msg.id === pending && msg.success === false) {
    out.results.push(`error:${msg.error}`); pending = null; next();
  } else if (msg.type === "response" && msg.id === "state") {
    const m = msg.data?.model; out.finalModel = m ? `${m.provider}/${m.id}` : null;
    console.log(JSON.stringify(out)); child.kill(); process.exit(0);
  }
});
setTimeout(() => { console.log(JSON.stringify({ ...out, timeout: true })); child.kill(); process.exit(1); }, 60000);
