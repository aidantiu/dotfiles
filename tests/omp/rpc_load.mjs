// Starts the user's real omp in RPC mode, sends only a model switch to the current model + get_state (no prompt,
// so no model request), and dumps every frame plus stderr. Used to prove extensions load.
import { spawn } from "node:child_process";
import readline from "node:readline";
const child = spawn("omp", ["--mode", "rpc", "--no-session"], { stdio: ["pipe", "pipe", "pipe"] });
const send = (o) => child.stdin.write(JSON.stringify(o) + "\n");
child.stderr.on("data", (d) => process.stdout.write(d));
let ready = false;
const done = () => { console.log(JSON.stringify({ ready })); child.kill(); process.exit(0); };
readline.createInterface({ input: child.stdout }).on("line", (line) => {
  console.log(line);
  let m; try { m = JSON.parse(line); } catch { return; }
  if (m.type === "ready") { ready = true; send({ id: "s", type: "get_state" }); }
  else if (m.type === "response" && m.id === "s") {
    const mod = m.data?.model;
    if (mod) send({ id: "m", type: "set_model", provider: mod.provider, modelId: mod.id });
    else setTimeout(done, 1500);
  } else if (m.type === "response" && m.id === "m") setTimeout(done, 1500);
});
setTimeout(() => { console.log("timeout"); child.kill(); process.exit(1); }, 50000);
