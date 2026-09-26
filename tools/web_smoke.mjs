#!/usr/bin/env node
// Initial2D 웹 빌드 헤드리스 검수 (R3, docs/plans/r3-emscripten.md 6절).
//
//   node tools/web_smoke.mjs                       # build-web/site 를 띄워 알데바란 타이틀까지 확인
//   node tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png   # 20 프레임 캡처를 골든과 대조
//   node tools/web_smoke.mjs --headed              # 창을 띄워 보면서
//
// 하는 일 (순서대로, 하나라도 실패하면 종료 코드 1):
//   1. build-web/site 를 임의 포트의 정적 서버로 연다 (.wasm 은 application/wasm).
//   2. 헤드리스 크로미움(InitialEditor 의 Playwright)으로 페이지를 열고 "실행" 을 누른다.
//   3. 엔진 시작 줄("Initial2D web: renderer=...")과 20 프레임 캡처(INITIAL2D_SCREENSHOT 을 MEMFS 로)를 기다린다.
//   4. canvas 를 build-web/smoke.png 로 찍고, MEMFS 의 BMP 를 build-web/smoke_frame20.bmp 로 꺼낸다.
//      --golden 이 있으면 PIL 로 골든과 대조한다 (허용 오차는 네이티브 골든과 같은 식: 픽셀 차이 비율).
//   5. 키보드: canvas 에 포커스를 주고 아래 화살표와 Enter 를 보내 "조작 방법" 설명 창이 뜨는지 본다
//      (canvas 화면의 픽셀 변화량으로. 커서 깜빡임은 2% 아래, 설명 창은 그보다 훨씬 크다).
//   6. reload() 가 true 를 돌려주고 reload() 와 quit() export 가 콘솔에 자기 줄을 남기는지 본다.
//   7. 두 번째 페이지: 파일 한 장짜리 main.lua 를 올려 os.getenv 가 설정 객체를 보는지 본다.
//   1~7 에서는 콘솔에 "Lua error", "abort(", "RuntimeError", 페이지 오류가 보이면 실패다.
//
// 오류 처리 (8~11, docs/plans/r3-emscripten.md 8절). 각 경우를 새 페이지의 파일 몇 장짜리 프로젝트로 띄우고,
// 페이지 오류(잡히지 않은 JS 예외), "Uncaught", "RuntimeError", "Aborted(", "fatal:" 이 보이면 실패다.
//   8. 시작 때의 Lua 문법 오류: 네이티브와 같은 오류 줄이 printErr 로 나오고, bootInitial2D 는 예외 없이
//      돌아오며, 루프가 멈추고 onExit(1) 이 한 번 온다.
//   9. Update 의 런타임 오류(error("boom")): 같은 형식의 줄, destroy 훅은 불리지 않고, onExit(1).
//  10. reload(): 고장 난 파일이면 false 와 오류 줄, 루프는 돌고(frames() 가 는다) 화면에서 스크립트 그림이
//      사라진다. 고친 파일이면 true 이고 게임이 다시 그린다. pcall 안의 오류는 Lua 가 잡는다.
//  11. quit() 뒤 onExit(0) 이 한 번, frames() 는 멈춘다. errorText() 는 늘 문자열을 준다.
//   네이티브 실행 파일(--native, 기본 build/Initial2D)이 있으면 8 과 9 의 파일을 헤드리스로 돌려
//   오류 줄이 글자 그대로 같은지도 본다.
//
// mruby (12~13, docs/plans/r3-emscripten.md 9절). --lua-only 로 mruby 없이 빌드한 사이트를 검수할 때만 건너뛴다.
// 12 의 대조는 모두 네이티브 골든 검사와 같은 규칙이다 (채널당 24 넘게 다른 픽셀이 2% 이하).
//  12a. Ruby 게임: 사이트의 프로젝트 파일에서 scripts/lua/ 를 빼고 game.json 에 "script": "mruby" 를 넣어 띄운다
//       (Lua 로 떨어지면 main.lua 가 없어 오류가 난다). features() 가 "lua mruby wasm" 이고, 20 프레임 캡처
//       (--frame-out 옆의 smoke_mruby_frame20.bmp)를 1~4 의 Lua 캡처와 --golden 의 골든에 견준다.
//  12b. 네이티브 대조: Ruby 인수 씬(tests/engine/scenes/mruby_aldebaran_scene.rb)을 scripts/ruby/main.rb 로 넣고
//       INITIAL2D_ALDEBARAN_STOP=title 로 타이틀을 고정한다 (네이티브 골든 검사와 같은 길). 같은 파일을 네이티브로
//       돌린 20 프레임과 골든에 견준다. 게임 그대로는 헤드리스 네이티브의 프레임 간격이 달라 20 프레임에 메뉴 창이
//       덜 열리므로 12a 에서는 네이티브와 견주지 않는다. 고정한 타이틀에서도 커서 깜빡임의 위상은 다를 수 있고,
//       그 칸(약 1.7%)이 허용치 안에 든다.
//  13. Ruby 오류: rescue 와 C++ 바인딩이 일으킨 예외의 rescue, update 의 raise, render 에서 바인딩이 일으킨
//      TypeError, 시작 때 문법 오류, reload() 의 고장 난 파일과 고친 파일. 오류 줄(역추적 포함)은 네이티브와
//      글자 그대로 같고, 8~11 과 같이 JS 쪽 오류가 없어야 한다.
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "..");

const args = process.argv.slice(2);
function opt(name, fallback) {
	const i = args.indexOf(name);
	return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
}
const SITE = path.resolve(repo, opt("--site", "build-web/site"));
const OUT_PNG = path.resolve(repo, opt("--out", "build-web/smoke.png"));
const OUT_BMP = path.resolve(repo, opt("--frame-out", "build-web/smoke_frame20.bmp"));
const OUT_HELP_PNG = path.resolve(repo, opt("--help-out", "build-web/smoke_help.png"));
const GOLDEN = args.includes("--golden") ? path.resolve(repo, opt("--golden", "tests/golden/aldebaran_title.png")) : null;
const TIMEOUT = Number(opt("--timeout", "15000"));
const HEADED = args.includes("--headed");
const PLAYWRIGHT_DIR = process.env.PLAYWRIGHT_DIR || "/Users/u/InitialEditor/node_modules/playwright";
const NATIVE = path.resolve(repo, opt("--native", "build/Initial2D"));
const SHOTS_DIR = path.dirname(OUT_PNG);
const LUA_ONLY = args.includes("--lua-only");
const OUT_MRUBY_BMP = path.join(path.dirname(OUT_BMP), "smoke_mruby_frame20.bmp");
// tests/run_engine_tests.py 의 GOLDEN_PIXEL_TOL, GOLDEN_DIFF_RATIO 와 같은 값
const GOLDEN_PIXEL_TOL = 24;
const GOLDEN_DIFF_RATIO = 0.02;

const MIME = {
	".html": "text/html; charset=utf-8",
	".js": "text/javascript; charset=utf-8",
	".mjs": "text/javascript; charset=utf-8",
	".wasm": "application/wasm",
	".json": "application/json; charset=utf-8",
	".png": "image/png",
	".jpg": "image/jpeg",
	".ogg": "audio/ogg",
	".wav": "audio/wav",
	".lua": "text/plain; charset=utf-8",
	".rb": "text/plain; charset=utf-8",
	".fnt": "text/plain; charset=utf-8",
};

// 두 그림의 픽셀 차이 비율 (PIL). 크기가 다르면 b 의 크기로 맞춘다. PIL 이 없으면 null.
function pixelDiff(a, b) {
	const py = `
import sys
from PIL import Image, ImageChops
a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
if a.size != b.size:
    a = a.resize(b.size, Image.BILINEAR)
diff = ImageChops.difference(a, b).convert("L")
px = list(diff.getdata())
changed = sum(1 for v in px if v > 40)
print("size=%dx%d changed=%d/%d ratio=%.4f mean=%.2f" % (b.size[0], b.size[1], changed, len(px), changed / len(px), sum(px) / len(px)))
`;
	const r = spawnSync("python3", ["-c", py, a, b], { encoding: "utf-8" });
	if (r.status !== 0) {
		return null;
	}
	const line = r.stdout.trim();
	return { line, ratio: Number((line.match(/ratio=([0-9.]+)/) || [])[1]) };
}

function fail(message) {
	console.error("web_smoke: FAIL " + message);
	process.exit(1);
}

function expect(cond, message) {
	if (!cond) fail(message);
}

// 그림에서 rgb 에 가까운(채널마다 tol 안) 픽셀 수 (PIL). PIL 이 없으면 null.
function countColor(file, rgb, tol = 40) {
	const py = `
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
r, g, b, tol = (int(v) for v in sys.argv[2:6])
print(sum(1 for (pr, pg, pb) in im.getdata() if abs(pr - r) <= tol and abs(pg - g) <= tol and abs(pb - b) <= tol))
`;
	const r = spawnSync("python3", ["-c", py, file, ...rgb.map(String), String(tol)], { encoding: "utf-8" });
	if (r.status !== 0) {
		return null;
	}
	return Number(r.stdout.trim());
}

// 캡처 a 를 골든 b 와 네이티브 골든 검사(tests/run_engine_tests.py 의 check_golden)와 같은 규칙으로 대조한다.
// a 를 b 의 크기로 맞춘 뒤, 채널 하나라도 GOLDEN_PIXEL_TOL 보다 다른 픽셀의 비율. PIL 이 없으면 null.
function goldenDiff(a, b) {
	const py = `
import sys
from PIL import Image, ImageChops
a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
if a.size != b.size:
    a = a.resize(b.size, Image.BILINEAR)
r, g, bl = ImageChops.difference(a, b).split()
worst = ImageChops.lighter(ImageChops.lighter(r, g), bl)
tol = int(sys.argv[3])
bad = sum(1 for v in worst.getdata() if v > tol)
total = b.size[0] * b.size[1]
print("size=%dx%d bad=%d/%d ratio=%.4f max=%d" % (b.size[0], b.size[1], bad, total, bad / total, max(worst.getdata())))
`;
	const r = spawnSync("python3", ["-c", py, a, b, String(GOLDEN_PIXEL_TOL)], { encoding: "utf-8" });
	if (r.status !== 0) {
		return null;
	}
	const line = r.stdout.trim();
	return { line, ratio: Number((line.match(/ratio=([0-9.]+)/) || [])[1]) };
}

// 네이티브 엔진으로 같은 파일을 헤드리스, 유한 실행으로 돌린다. 실행 파일이 없으면 null.
//   files        경로 -> 내용
//   copyFrom     { root, rels }: root 아래의 rels 를 같은 상대 경로로 더 복사한다 (사이트의 프로젝트 폴더)
//   env          더할 환경 변수
//   frame        0 보다 크면 그 프레임을 캡처해 BMP 바이트로 돌려준다
// 돌려주는 것: 종료 코드, stderr 의 줄, "Lua error" 줄, 캡처
function runNative(files, { copyFrom = null, env = {}, frame = 0 } = {}) {
	if (!fs.existsSync(NATIVE)) {
		return null;
	}
	const work = fs.mkdtempSync(path.join(os.tmpdir(), "initial2d-websmoke-"));
	try {
		if (copyFrom) {
			for (const rel of copyFrom.rels) {
				const full = path.join(work, rel);
				fs.mkdirSync(path.dirname(full), { recursive: true });
				fs.copyFileSync(path.join(copyFrom.root, rel), full);
			}
		}
		for (const [rel, data] of Object.entries(files)) {
			const full = path.join(work, rel);
			fs.mkdirSync(path.dirname(full), { recursive: true });
			fs.writeFileSync(full, data);
		}
		const runEnv = { ...process.env, SDL_VIDEODRIVER: "dummy", INITIAL2D_EXIT_AFTER: "60", ...env };
		const shotPath = path.join(work, "native_shot.bmp");
		if (frame > 0) {
			runEnv.INITIAL2D_SCREENSHOT = shotPath;
			runEnv.INITIAL2D_SCREENSHOT_FRAME = String(frame);
		}
		const r = spawnSync(NATIVE, [], { cwd: work, env: runEnv, encoding: "utf-8", timeout: 60000 });
		const outLines = (r.stdout || "").split("\n");
		const errLines = (r.stderr || "").split("\n");
		return {
			code: r.status,
			errLines,
			errorLines: [...outLines, ...errLines].filter((l) => l.startsWith("Lua error")),
			shot: frame > 0 && fs.existsSync(shotPath) ? fs.readFileSync(shotPath) : null,
		};
	} finally {
		fs.rmSync(work, { recursive: true, force: true });
	}
}

// 네이티브 실행 파일이 mruby 를 갖고 있는가 (--features). 실행 파일이 없으면 false.
function nativeHasMRuby() {
	if (!fs.existsSync(NATIVE)) {
		return false;
	}
	const r = spawnSync(NATIVE, ["--features"], {
		env: { ...process.env, SDL_VIDEODRIVER: "dummy" },
		encoding: "utf-8",
		timeout: 30000,
	});
	return /\bmruby\b/.test((r.stdout || "") + (r.stderr || ""));
}

if (!fs.existsSync(path.join(SITE, "Initial2D.wasm"))) {
	fail(`${SITE}/Initial2D.wasm 가 없습니다. 먼저 tools/build_web.sh`);
}

// 1. 정적 서버
const server = http.createServer((req, res) => {
	const url = new URL(req.url, "http://localhost");
	let rel = decodeURIComponent(url.pathname);
	if (rel.endsWith("/")) rel += "index.html";
	const file = path.join(SITE, path.normalize(rel));
	if (!file.startsWith(SITE) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
		res.writeHead(404);
		res.end("not found");
		return;
	}
	res.writeHead(200, { "Content-Type": MIME[path.extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
	fs.createReadStream(file).pipe(res);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}`;
console.log(`web_smoke: serving ${SITE} at ${base}`);

// 2. 브라우저
const { chromium } = await import(pathToFileURL(path.join(PLAYWRIGHT_DIR, "index.mjs")).href);
const browser = await chromium.launch({ headless: !HEADED });
const context = await browser.newContext({ viewport: { width: 1280, height: 1000 }, deviceScaleFactor: 1 });

const BAD = /Lua error|abort\(|RuntimeError|Uncaught|Aborted\(/;

function attachConsole(page, lines) {
	page.on("console", (msg) => {
		const text = msg.text();
		lines.push(text);
		if (process.env.WEB_SMOKE_VERBOSE) console.log("  [console] " + text);
	});
	page.on("pageerror", (e) => {
		lines.push("pageerror: " + e.message);
	});
}

async function waitFor(lines, predicate, what, timeout = TIMEOUT) {
	const start = Date.now();
	while (Date.now() - start < timeout) {
		const bad = lines.find((l) => BAD.test(l));
		if (bad) fail(`콘솔 오류: ${bad}`);
		if (lines.some(predicate)) return;
		await new Promise((r) => setTimeout(r, 100));
	}
	fail(`${what} 를 ${timeout}ms 안에 보지 못했습니다. 마지막 콘솔:\n  ${lines.slice(-12).join("\n  ")}`);
}

// ---- 8~13 이 함께 쓰는 도우미. 파일 몇 장짜리 프로젝트를 새 페이지로 띄우고 JS 쪽 오류를 지켜본다 ----
// 엔진의 stdout, stderr 는 "[stdout] ", "[stderr] " 를 붙여 콘솔에 낸다. 그 줄에서는 fatal 과 abort 만 본다
// (Ruby 의 예외 클래스 RuntimeError 는 스크립트 오류 줄에 그대로 나온다). 그 밖의 콘솔 줄과 페이지 오류는 JS 쪽이다.
const JS_BAD = /pageerror|Uncaught|RuntimeError|Aborted\(|abort\(|fatal:/;
const ENGINE_LINE = /^\[(stdout|stderr)\] /;
const ENGINE_BAD = /^(fatal:|Aborted\(|abort\()/;
const jsErrors = (lines) => lines.filter((l) => {
	const m = ENGINE_LINE.exec(l);
	return m ? ENGINE_BAD.test(l.slice(m[0].length)) : JS_BAD.test(l);
});

// 새 페이지에서 files 로 엔진을 띄운다. print, printErr, onExit 을 페이지 전역에 모은다.
// fetched({ root, rels })가 있으면 페이지가 사이트에서 그 파일들을 내려받아 files 아래에 깐다 (큰 프로젝트)
async function bootProject(files, env = {}, fetched = null) {
	const pg = await context.newPage();
	const lines = [];
	attachConsole(pg, lines);
	await pg.goto(`${base}/`);
	const bootError = await pg.evaluate(async ({ files, env, fetched }) => {
		const { bootInitial2D } = await import("./initial2d-loader.js");
		if (fetched) {
			const all = {};
			await Promise.all(fetched.rels.map(async (rel) => {
				const response = await fetch(`${fetched.root}/${rel}`);
				if (!response.ok) throw new Error(`${rel}: HTTP ${response.status}`);
				all[rel] = new Uint8Array(await response.arrayBuffer());
			}));
			files = Object.assign(all, files);
		}
		window.__out = [];
		window.__err = [];
		window.__exits = [];
		try {
			window.__game = await bootInitial2D({
				canvas: document.getElementById("canvas"),
				files,
				env,
				print: (l) => { window.__out.push(l); console.log("[stdout] " + l); },
				printErr: (l) => { window.__err.push(l); console.log("[stderr] " + l); },
				onExit: (code) => { window.__exits.push(code); },
			});
			return null;
		} catch (e) {
			return String((e && e.stack) || e);
		}
	}, { files, env, fetched });
	expect(bootError === null, `bootInitial2D 가 예외를 던졌습니다: ${bootError}`);
	return { pg, lines };
}

const state = (pg) => pg.evaluate(() => ({
	out: window.__out.slice(),
	err: window.__err.slice(),
	exits: window.__exits.slice(),
	frames: window.__game.frames(),
}));

async function until(pg, lines, predicate, what) {
	const start = Date.now();
	for (;;) {
		const bad = jsErrors(lines);
		expect(bad.length === 0, `${what}: JS 쪽 오류 ${bad[0]}`);
		const st = await state(pg);
		if (predicate(st)) return st;
		if (Date.now() - start > TIMEOUT) {
			fail(`${what} 를 ${TIMEOUT}ms 안에 보지 못했습니다. err=${JSON.stringify(st.err.slice(-6))} out=${JSON.stringify(st.out.slice(-6))} exits=${JSON.stringify(st.exits)}`);
		}
		await new Promise((r) => setTimeout(r, 100));
	}
}

// ---- 8~11. 오류 처리 (docs/plans/r3-emscripten.md 8절) ----
// 오류 줄은 네이티브 엔진이 같은 파일에서 찍는 것과 글자 그대로 같아야 한다 (에디터의 오류 링크가 같은 파서를 쓴다).
async function errorCases() {
	function sameAsNative(files, expectedLine, label) {
		const n = runNative(files);
		if (n === null) {
			console.log(`web_smoke: ${label} 네이티브 대조 건너뜀 (${path.relative(repo, NATIVE)} 가 없습니다)`);
			return;
		}
		expect(n.code === 1, `${label}: 네이티브 종료 코드가 1 이 아닙니다 (${n.code})`);
		expect(n.errorLines[0] === expectedLine,
			`${label}: 네이티브 오류 줄이 다릅니다\n  네이티브: ${n.errorLines[0]}\n  기대:     ${expectedLine}`);
		console.log(`web_smoke: ${label} 네이티브도 같은 줄, 종료 코드 1`);
	}

	// 8. 시작 때의 문법 오류
	{
		const files = { "scripts/lua/main.lua": 'print("syn:loaded")\nfunction Initialize(\nend\n' };
		const LINE = "Lua error in scripts/lua/main.lua: ./scripts/lua/main.lua:3: <name> or '...' expected near 'end'";
		const { pg, lines } = await bootProject(files);
		const st = await until(pg, lines, (s) => s.exits.length > 0, "8. 문법 오류 뒤 onExit");
		expect(st.err.includes(LINE), `8. 오류 줄이 없습니다. stderr=${JSON.stringify(st.err)}`);
		expect(st.exits[0] === 1, `8. onExit 코드가 1 이 아닙니다: ${st.exits[0]}`);
		expect(st.err.some((l) => l.includes("Initial2D web: main loop stopped")), "8. 루프가 멈춘 줄이 없습니다");
		expect(!st.out.includes("syn:loaded"), "8. 문법 오류인 파일이 실행되었습니다");
		await pg.waitForTimeout(400);
		const later = await state(pg);
		expect(later.exits.length === 1, `8. onExit 이 한 번이 아닙니다: ${JSON.stringify(later.exits)}`);
		expect(jsErrors(lines).length === 0, `8. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 8. 시작 때 문법 오류 -> "${LINE}", onExit(1), JS 예외 없음`);
		sameAsNative(files, LINE, "8.");
		await pg.close();
	}

	// 9. Update 의 런타임 오류
	{
		const files = { "scripts/lua/main.lua": [
			"local n = 0",
			'function Initialize() print("rt:init") end',
			"function Update(elapsed)",
			"  n = n + 1",
			'  if n == 3 then error("boom") end',
			"end",
			"function Render() end",
			'function Destroy() print("rt:destroy") end',
		].join("\n") + "\n" };
		const LINE = "Lua error in update: ./scripts/lua/main.lua:5: boom";
		const { pg, lines } = await bootProject(files);
		const st = await until(pg, lines, (s) => s.exits.length > 0, "9. 런타임 오류 뒤 onExit");
		expect(st.out.includes("rt:init"), "9. init 이 돌지 않았습니다");
		expect(st.err.includes(LINE), `9. 오류 줄이 없습니다. stderr=${JSON.stringify(st.err)}`);
		expect(st.exits[0] === 1, `9. onExit 코드가 1 이 아닙니다: ${st.exits[0]}`);
		expect(!st.out.includes("rt:destroy"), "9. 오류 뒤에 destroy 훅이 불렸습니다 (네이티브는 부르지 않는다)");
		expect(st.frames > 0, `9. frames() 가 0 입니다`);
		await pg.waitForTimeout(400);
		const later = await state(pg);
		expect(later.frames === st.frames, `9. 루프가 멈춘 뒤에도 frames() 가 늘었습니다 (${st.frames} -> ${later.frames})`);
		expect(later.exits.length === 1, `9. onExit 이 한 번이 아닙니다: ${JSON.stringify(later.exits)}`);
		expect(jsErrors(lines).length === 0, `9. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 9. Update 의 오류 -> "${LINE}", onExit(1), frames()=${st.frames} 에서 멈춤`);
		sameAsNative(files, LINE, "9.");
		await pg.close();
	}

	// 10. reload: 고장 난 파일, 고친 파일. 11. quit 과 errorText
	{
		// 8 배율로 41x41 논리 점을 칠한다 (canvas 에서 328x328 픽셀). 색으로 어느 스크립트가 그렸는지 본다
		const drawing = (tag, r, g, b) => [
			"local rendered = false",
			`function Initialize() SetRenderScale(8) print("${tag}:init") end`,
			"function Update(elapsed) end",
			"function Render()",
			`  if not rendered then rendered = true print("${tag}:render") end`,
			`  draw_set_color(${r}, ${g}, ${b}, 255)`,
			"  for y = 20, 60 do for x = 20, 60 do draw_point(x, y) end end",
			"end",
			`function Destroy() print("${tag}:destroy") end`,
		].join("\n") + "\n";
		const GOOD = 'local ok, msg = pcall(error, "x")\nprint("pcall ok=" .. tostring(ok) .. " msg=" .. tostring(msg))\n'
			+ drawing("good", 255, 0, 0);
		const BROKEN = "function Initialize(\nend\n";
		const FIXED = drawing("fixed", 0, 160, 0);
		const LINE = "Lua error in scripts/lua/main.lua: ./scripts/lua/main.lua:2: <name> or '...' expected near 'end'";
		const RED = [255, 0, 0];
		const GREEN = [0, 160, 0];
		const BLOCK = 328 * 328;
		const shot = async (pg, name) => {
			const file = path.join(SHOTS_DIR, name);
			fs.mkdirSync(SHOTS_DIR, { recursive: true });
			await pg.locator("#canvas").screenshot({ path: file });
			return file;
		};

		const { pg, lines } = await bootProject({ "scripts/lua/main.lua": GOOD });
		let st = await until(pg, lines, (s) => s.out.includes("good:render") && s.frames > 10, "10. 첫 스크립트가 그린다");
		expect(st.out.includes("pcall ok=false msg=x"), `10. pcall 이 Lua 오류를 잡지 못했습니다. stdout=${JSON.stringify(st.out)}`);
		const shotGood = await shot(pg, "smoke_reload_good.png");

		const r1 = await pg.evaluate((src) => window.__game.reload({ "scripts/lua/main.lua": src }), BROKEN);
		expect(r1 === false, `10. 고장 난 파일의 reload() 가 false 가 아닙니다: ${r1}`);
		st = await state(pg);
		expect(st.err.includes(LINE), `10. reload 의 오류 줄이 없습니다. stderr=${JSON.stringify(st.err.slice(-6))}`);
		expect(st.out.includes("good:destroy"), "10. reload 가 이전 VM 의 destroy 훅을 부르지 않았습니다");
		expect(st.exits.length === 0, `10. 고장 난 reload 뒤에 루프가 멈췄습니다: ${JSON.stringify(st.exits)}`);
		const framesAfterBroken = st.frames;
		st = await until(pg, lines, (s) => s.frames > framesAfterBroken + 10, "10. 고장 난 reload 뒤에도 루프가 돈다");
		const shotBroken = await shot(pg, "smoke_reload_broken.png");

		const r2 = await pg.evaluate((src) => window.__game.reload({ "scripts/lua/main.lua": src }), FIXED);
		expect(r2 === true, `10. 고친 파일의 reload() 가 true 가 아닙니다: ${r2}`);
		st = await until(pg, lines, (s) => s.out.includes("fixed:render"), "10. 고친 스크립트가 다시 그린다");
		expect(st.out.includes("fixed:init"), "10. 고친 스크립트의 init 이 돌지 않았습니다");
		expect(st.err.some((l) => l.includes("HotReload: reloaded (web)")), "10. reload 성공 줄이 없습니다");
		await pg.waitForTimeout(300);
		const shotFixed = await shot(pg, "smoke_reload_fixed.png");

		const redGood = countColor(shotGood, RED);
		if (redGood === null) {
			console.log("web_smoke: 10. 화면 대조 건너뜀 (python3 과 PIL 이 필요합니다)");
		} else {
			const redBroken = countColor(shotBroken, RED);
			const greenFixed = countColor(shotFixed, GREEN);
			const redFixed = countColor(shotFixed, RED);
			console.log(`web_smoke: 10. 화면 red(good)=${redGood} red(broken)=${redBroken} green(fixed)=${greenFixed} red(fixed)=${redFixed} (칸 ${BLOCK})`);
			expect(redGood > BLOCK * 0.5, "10. 첫 스크립트의 그림이 canvas 에 없습니다");
			expect(redBroken < BLOCK * 0.01, "10. 고장 난 reload 뒤에도 이전 그림이 남았습니다 (스크립트가 멈추지 않았다)");
			expect(greenFixed > BLOCK * 0.5 && redFixed < BLOCK * 0.01, "10. 고친 reload 뒤에 게임이 다시 그리지 않습니다");
		}
		console.log(`web_smoke: 10. reload(고장)=false 와 "${LINE}", 루프는 돈다. reload(고침)=true, 다시 그린다`);

		// 11. quit 뒤 onExit(0) 한 번, frames() 멈춤, 멈춘 뒤 reload 는 false. errorText 는 늘 문자열
		await pg.evaluate(() => window.__game.quit());
		st = await until(pg, lines, (s) => s.exits.length > 0, "11. quit 뒤 onExit");
		expect(st.exits[0] === 0, `11. quit 뒤 onExit 코드가 0 이 아닙니다: ${st.exits[0]}`);
		expect(st.err.some((l) => l.includes("Initial2D web: main loop stopped")), "11. 루프가 멈춘 줄이 없습니다");
		await pg.waitForTimeout(400);
		const later = await state(pg);
		expect(later.exits.length === 1, `11. onExit 이 한 번이 아닙니다: ${JSON.stringify(later.exits)}`);
		expect(later.frames === st.frames, `11. 멈춘 뒤에도 frames() 가 늘었습니다 (${st.frames} -> ${later.frames})`);
		const r3 = await pg.evaluate(() => window.__game.reload());
		expect(r3 === false, `11. 멈춘 엔진의 reload() 가 false 가 아닙니다: ${r3}`);
		const texts = await pg.evaluate(() => {
			const g = window.__game;
			return [
				g.errorText(new Error("boom")),
				g.errorText("plain"),
				g.errorText(undefined),
				g.errorText(null),
				g.errorText({ message: "" }),
				typeof g.module.getExceptionMessage,
			];
		});
		expect(texts[0] === "boom" && texts[1] === "plain", `11. errorText 가 메시지를 돌려주지 않습니다: ${JSON.stringify(texts)}`);
		expect(texts.slice(0, 5).every((t) => typeof t === "string" && t.length > 0), `11. errorText 가 빈 값을 돌려주었습니다: ${JSON.stringify(texts)}`);
		expect(texts[5] === "function", "11. 빌드가 getExceptionMessage 를 내보내지 않습니다 (EXPORTED_RUNTIME_METHODS)");
		expect(jsErrors(lines).length === 0, `10/11. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 11. quit() -> onExit(0) 한 번, frames()=${st.frames} 에서 멈춤, errorText 동작`);
		await pg.close();
	}
}

// ---- 12~13. mruby (docs/plans/r3-emscripten.md 9절) ----
// 같은 엔진의 두 번째 언어가 브라우저에서도 네이티브와 같게 돈다. 오류 줄은 역추적까지 글자 그대로 같다.
async function mrubyCases() {
	// lines 안에서 block 이 연속으로 나오는 첫 자리. 없으면 -1
	const findBlock = (lines, block) => {
		for (let i = 0; i + block.length <= lines.length; i++) {
			if (block.every((b, k) => lines[i + k] === b)) return i;
		}
		return -1;
	};

	// 네이티브도 같은 파일에서 같은 줄 묶음을 stderr 에 찍고 종료 코드 1 로 끝나는가
	const nativeHasRuby = nativeHasMRuby();
	function sameAsNative(files, block, label) {
		if (!nativeHasRuby) {
			console.log(`web_smoke: ${label} 네이티브 대조 건너뜀 (${path.relative(repo, NATIVE)} 가 없거나 mruby 가 없습니다)`);
			return;
		}
		const n = runNative(files, { env: { INITIAL2D_SCRIPT: "" } });
		expect(n.code === 1, `${label}: 네이티브 종료 코드가 1 이 아닙니다 (${n.code})`);
		expect(findBlock(n.errLines, block) >= 0,
			`${label}: 네이티브 오류 줄이 다릅니다\n  네이티브: ${JSON.stringify(n.errLines.filter((l) => l && !/^(INFO|SetAppIcon|libpng)/.test(l)))}\n  기대:     ${JSON.stringify(block)}`);
		console.log(`web_smoke: ${label} 네이티브도 같은 줄, 종료 코드 1`);
	}

	const SCRIPT_ERROR = /^(Lua error|mruby: )/;

	// 12. Ruby 게임. 사이트의 프로젝트에서 scripts/lua/ 를 뺀다 (Lua 로 떨어지면 main.lua 가 없어 오류가 난다)
	const manifest = JSON.parse(fs.readFileSync(path.join(SITE, "project.json"), "utf-8"));
	const root = manifest.root || "project";
	const rubyRels = manifest.files.filter((rel) => !rel.startsWith("scripts/lua/") && rel !== "game.json");
	expect(rubyRels.includes("scripts/ruby/main.rb"),
		"12. 사이트에 scripts/ruby/main.rb 가 없습니다 (tools/web_stage.py 가 scripts/ruby/ 를 스테이징해야 한다)");

	// 부팅해 20 프레임 캡처(MEMFS)를 꺼내 out 에 쓴다. 스크립트 오류, 루프 정지, JS 쪽 오류는 실패
	async function captureFrame20(label, files, env, rels, out) {
		const { pg, lines } = await bootProject(files,
			{ ...env, INITIAL2D_SCREENSHOT: "/project/shot.bmp", INITIAL2D_SCREENSHOT_FRAME: "20", INITIAL2D_NO_RTP: "1" },
			{ root, rels });
		const features = await pg.evaluate(() => window.__game.features());
		expect(features === "lua mruby wasm", `${label} features() 가 "lua mruby wasm" 이 아닙니다: ${features}`);
		const hasShot = () => pg.evaluate(() => {
			try { return window.__game.module.FS.analyzePath("/project/shot.bmp").exists; } catch (e) { return false; }
		});
		const start = Date.now();
		for (;;) {
			expect(jsErrors(lines).length === 0, `${label} JS 쪽 오류: ${jsErrors(lines)[0]}`);
			const st = await state(pg);
			expect(!st.err.some((l) => SCRIPT_ERROR.test(l)), `${label} 스크립트 오류: ${JSON.stringify(st.err.slice(-6))}`);
			expect(st.exits.length === 0, `${label} 20 프레임 전에 루프가 멈췄습니다: exits=${JSON.stringify(st.exits)} err=${JSON.stringify(st.err.slice(-6))}`);
			if (await hasShot()) break;
			expect(Date.now() - start < TIMEOUT, `${label} 20 프레임 캡처가 MEMFS 에 생기지 않았습니다`);
			await new Promise((r) => setTimeout(r, 100));
		}
		const bmp = await pg.evaluate(() => Array.from(window.__game.module.FS.readFile("/project/shot.bmp")));
		fs.mkdirSync(path.dirname(out), { recursive: true });
		fs.writeFileSync(out, Buffer.from(bmp));
		await pg.evaluate(() => window.__game.quit());
		const st = await until(pg, lines, (s) => s.exits.length > 0, `${label} quit 뒤 onExit`);
		expect(st.exits[0] === 0, `${label} quit 뒤 onExit 코드가 0 이 아닙니다: ${st.exits[0]}`);
		expect(!st.err.some((l) => SCRIPT_ERROR.test(l)), `${label} 스크립트 오류: ${JSON.stringify(st.err.slice(-6))}`);
		await pg.close();
		console.log(`web_smoke: ${label} features=${features}, frame 20 -> ${out}`);
	}

	// 같은 규칙(채널당 24, 픽셀 2%)으로 대조한다
	function compare(label, frame, other, what) {
		const d = goldenDiff(frame, other);
		if (d === null) {
			console.log(`web_smoke: ${label} ${what} 대조 건너뜀 (python3 과 PIL 이 필요합니다)`);
			return;
		}
		console.log(`web_smoke: ${label} ${what} ${d.line}`);
		expect(d.ratio <= GOLDEN_DIFF_RATIO,
			`${label} 20 프레임이 ${what} 와 ${(d.ratio * 100).toFixed(2)}% 다릅니다 (허용 ${GOLDEN_DIFF_RATIO * 100}%)`);
	}

	// 12a. 게임 그대로. game.json 의 "script": "mruby" 로 고른다. 같은 브라우저의 Lua 판(1~4)과 골든에 견준다.
	//      (네이티브의 실제 게임은 헤드리스에서 프레임 간격이 달라 20 프레임에 메뉴 창이 덜 열린다. 네이티브 대조는 12b)
	{
		const game = manifest.files.includes("game.json")
			? JSON.parse(fs.readFileSync(path.join(SITE, root, "game.json"), "utf-8"))
			: {};
		game.script = "mruby";
		await captureFrame20("12a. Ruby 게임 (game.json \"script\": \"mruby\")", { "game.json": JSON.stringify(game) + "\n" },
			{}, rubyRels, OUT_MRUBY_BMP);
		compare("12a.", OUT_MRUBY_BMP, OUT_BMP, "Lua 판(1~4 의 캡처)");
		if (GOLDEN) {
			compare("12a.", OUT_MRUBY_BMP, GOLDEN, `골든 ${path.relative(repo, GOLDEN)}`);
		}
	}

	// 12b. 네이티브 골든 검사와 같은 길: Ruby 인수 씬(tests/engine/scenes/mruby_aldebaran_scene.rb)을
	//      scripts/ruby/main.rb 로 넣고 INITIAL2D_ALDEBARAN_STOP=title 로 타이틀을 고정한다. main.lua 가 없으므로
	//      엔진이 스스로 mruby 를 고른다 (ScriptRuntime 의 3번 규칙). 같은 파일을 네이티브로도 돌려 20 프레임을 견준다.
	{
		const scene = fs.readFileSync(path.join(repo, "tests", "engine", "scenes", "mruby_aldebaran_scene.rb"));
		const replay = fs.readFileSync(path.join(repo, "tests", "ruby", "input_replay.rb"));
		const rels = rubyRels.filter((rel) => rel !== "scripts/ruby/main.rb");
		const files = { "scripts/ruby/main.rb": scene, "scripts/ruby/rbtests/input_replay.rb": replay };
		const out = path.join(path.dirname(OUT_BMP), "smoke_mruby_scene_frame20.bmp");
		// Buffer 는 페이지로 넘어가지 않으므로 문자열로 준다 (둘 다 UTF-8 텍스트)
		await captureFrame20("12b. Ruby 인수 씬 (STOP=title)",
			{ "scripts/ruby/main.rb": scene.toString("utf-8"), "scripts/ruby/rbtests/input_replay.rb": replay.toString("utf-8") },
			{ INITIAL2D_ALDEBARAN_STOP: "title" }, rels, out);
		if (GOLDEN) {
			compare("12b.", out, GOLDEN, `골든 ${path.relative(repo, GOLDEN)}`);
		}
		if (nativeHasRuby) {
			const n = runNative(files, {
				copyFrom: { root: path.join(SITE, root), rels },
				env: { INITIAL2D_SCRIPT: "", INITIAL2D_ALDEBARAN_STOP: "title", INITIAL2D_NO_RTP: "1", INITIAL2D_EXIT_AFTER: "30" },
				frame: 20,
			});
			expect(n.code === 0, `12b. 네이티브 mruby 가 종료 코드 ${n.code} 로 끝났습니다: ${JSON.stringify(n.errLines.slice(-6))}`);
			expect(n.shot !== null, "12b. 네이티브 mruby 의 20 프레임 캡처가 없습니다");
			const nativeBmp = path.join(path.dirname(OUT_BMP), "smoke_mruby_scene_native_frame20.bmp");
			fs.writeFileSync(nativeBmp, n.shot);
			compare("12b.", out, nativeBmp, `네이티브 mruby(${path.relative(repo, NATIVE)})`);
		} else {
			console.log(`web_smoke: 12b. 네이티브 대조 건너뜀 (${path.relative(repo, NATIVE)} 가 없거나 mruby 가 없습니다)`);
		}
	}

	// 13a. rescue 두 가지(Ruby 의 raise, C++ 바인딩의 raise)는 Ruby 가 잡고, update 의 raise 는 게임을 끝낸다
	{
		const files = { "scripts/ruby/main.rb": [
			"$n = 0",
			"begin",
			'  raise "x"',
			"rescue => e",
			'  puts "rescue ok=#{e.message}"',
			"end",
			"begin",
			'  Graphics.draw_point("a", 1)',
			"rescue TypeError => e",
			'  puts "binding rescue=#{e.class}: #{e.message}"',
			"end",
			"def init",
			'  puts "rt:init"',
			"end",
			"def update(elapsed)",
			"  $n += 1",
			'  raise "boom" if $n == 3',
			"end",
			"def render",
			"end",
			"def destroy",
			'  puts "rt:destroy"',
			"end",
		].join("\n") + "\n" };
		const BLOCK = [
			"mruby: uncaught exception in update",
			"trace (most recent call last):",
			"\t[1] scripts/ruby/main.rb:21",
			"scripts/ruby/main.rb:17:in update: boom (RuntimeError)",
		];
		const { pg, lines } = await bootProject(files);
		const st = await until(pg, lines, (s) => s.exits.length > 0, "13a. update 의 raise 뒤 onExit");
		expect(st.out.includes("rescue ok=x"), `13a. Ruby 의 rescue 가 돌지 않았습니다. stdout=${JSON.stringify(st.out)}`);
		expect(st.out.includes("binding rescue=TypeError: String cannot be converted to Integer"),
			`13a. C++ 바인딩이 일으킨 TypeError 를 Ruby 가 잡지 못했습니다. stdout=${JSON.stringify(st.out)}`);
		expect(st.out.includes("rt:init"), "13a. init 이 돌지 않았습니다");
		expect(findBlock(st.err, BLOCK) >= 0, `13a. 오류 줄이 다릅니다. stderr=${JSON.stringify(st.err)}`);
		expect(st.exits[0] === 1, `13a. onExit 코드가 1 이 아닙니다: ${st.exits[0]}`);
		expect(!st.out.includes("rt:destroy"), "13a. 오류 뒤에 destroy 가 불렸습니다 (네이티브는 부르지 않는다)");
		await pg.waitForTimeout(400);
		const later = await state(pg);
		expect(later.frames === st.frames, `13a. 루프가 멈춘 뒤에도 frames() 가 늘었습니다 (${st.frames} -> ${later.frames})`);
		expect(later.exits.length === 1, `13a. onExit 이 한 번이 아닙니다: ${JSON.stringify(later.exits)}`);
		expect(jsErrors(lines).length === 0, `13a. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 13a. rescue 둘은 Ruby 가 잡고, update 의 raise -> "${BLOCK[0]}" 외 ${BLOCK.length - 1} 줄, onExit(1), frames()=${st.frames} 에서 멈춤`);
		sameAsNative(files, BLOCK, "13a.");
		await pg.close();
	}

	// 13b. render 에서 C++ 바인딩이 일으킨 TypeError (C++ 프레임을 지나는 raise 가 잡히지 않은 채 끝난다)
	{
		const files = { "scripts/ruby/main.rb": [
			"$n = 0",
			"def init",
			"end",
			"def update(elapsed)",
			"  $n += 1",
			"end",
			"def render",
			'  Graphics.set_color("red", 0, 0) if $n == 2',
			"end",
			"def destroy",
			'  puts "render:destroy"',
			"end",
		].join("\n") + "\n" };
		const BLOCK = [
			"mruby: uncaught exception in render",
			"trace (most recent call last):",
			"\t[2] scripts/ruby/main.rb:10",
			"\t[1] scripts/ruby/main.rb:8:in render",
			"scripts/ruby/main.rb:8:in set_color: String cannot be converted to Integer (TypeError)",
		];
		const { pg, lines } = await bootProject(files);
		const st = await until(pg, lines, (s) => s.exits.length > 0, "13b. render 의 TypeError 뒤 onExit");
		expect(findBlock(st.err, BLOCK) >= 0, `13b. 오류 줄이 다릅니다. stderr=${JSON.stringify(st.err)}`);
		expect(st.exits[0] === 1, `13b. onExit 코드가 1 이 아닙니다: ${st.exits[0]}`);
		expect(!st.out.includes("render:destroy"), "13b. 오류 뒤에 destroy 가 불렸습니다");
		await pg.waitForTimeout(300);
		expect(jsErrors(lines).length === 0, `13b. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 13b. render 의 바인딩 TypeError -> "${BLOCK[BLOCK.length - 1]}", onExit(1)`);
		sameAsNative(files, BLOCK, "13b.");
		await pg.close();
	}

	// 13c. 시작 때의 문법 오류
	{
		const files = { "scripts/ruby/main.rb": 'puts "syn:loaded"\ndef init(\nend\n' };
		const BLOCK = [
			"scripts/ruby/main.rb:3:3: syntax error, unexpected \"'end'\", expecting ')'",
			"mruby: uncaught exception in scripts/ruby/main.rb",
			"(unknown):0: syntax error (SyntaxError)",
		];
		const { pg, lines } = await bootProject(files);
		const st = await until(pg, lines, (s) => s.exits.length > 0, "13c. 문법 오류 뒤 onExit");
		expect(findBlock(st.err, BLOCK) >= 0, `13c. 오류 줄이 다릅니다. stderr=${JSON.stringify(st.err)}`);
		expect(st.exits[0] === 1, `13c. onExit 코드가 1 이 아닙니다: ${st.exits[0]}`);
		expect(!st.out.includes("syn:loaded"), "13c. 문법 오류인 파일이 실행되었습니다");
		expect(st.err.some((l) => l.includes("Initial2D web: main loop stopped")), "13c. 루프가 멈춘 줄이 없습니다");
		await pg.waitForTimeout(300);
		expect(jsErrors(lines).length === 0, `13c. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 13c. 시작 때 문법 오류 -> "${BLOCK[0]}" 외 ${BLOCK.length - 1} 줄, onExit(1)`);
		sameAsNative(files, BLOCK, "13c.");
		await pg.close();
	}

	// 13d. reload(): 고장 난 파일이면 false 와 같은 오류 줄, 루프는 돈다. 고친 파일이면 true 이고 다시 그린다
	{
		const drawing = (tag, r, g, b) => [
			"$rendered = false",
			"def init",
			"  Graphics.render_scale = 8",
			`  puts "${tag}:init"`,
			"end",
			"def update(elapsed)",
			"end",
			"def render",
			"  unless $rendered",
			"    $rendered = true",
			`    puts "${tag}:render"`,
			"  end",
			`  Graphics.set_color(${r}, ${g}, ${b}, 255)`,
			"  (20..60).each { |y| (20..60).each { |x| Graphics.draw_point(x, y) } }",
			"end",
			"def destroy",
			`  puts "${tag}:destroy"`,
			"end",
		].join("\n") + "\n";
		const BROKEN = "def init(\nend\n";
		const BLOCK = [
			"scripts/ruby/main.rb:2:3: syntax error, unexpected \"'end'\", expecting ')'",
			"mruby: uncaught exception in scripts/ruby/main.rb",
			"(unknown):0: syntax error (SyntaxError)",
		];
		const RED = [255, 0, 0];
		const GREEN = [0, 160, 0];
		const CELLS = 328 * 328;
		const shot = async (pg, name) => {
			const file = path.join(SHOTS_DIR, name);
			fs.mkdirSync(SHOTS_DIR, { recursive: true });
			await pg.locator("#canvas").screenshot({ path: file });
			return file;
		};

		const { pg, lines } = await bootProject({ "scripts/ruby/main.rb": drawing("good", 255, 0, 0) });
		let st = await until(pg, lines, (s) => s.out.includes("good:render") && s.frames > 10, "13d. 첫 Ruby 스크립트가 그린다");
		const shotGood = await shot(pg, "smoke_mruby_reload_good.png");

		const r1 = await pg.evaluate((src) => window.__game.reload({ "scripts/ruby/main.rb": src }), BROKEN);
		expect(r1 === false, `13d. 고장 난 파일의 reload() 가 false 가 아닙니다: ${r1}`);
		st = await state(pg);
		expect(findBlock(st.err, BLOCK) >= 0, `13d. reload 의 오류 줄이 다릅니다. stderr=${JSON.stringify(st.err.slice(-8))}`);
		expect(st.out.includes("good:destroy"), "13d. reload 가 이전 VM 의 destroy 를 부르지 않았습니다");
		expect(st.exits.length === 0, `13d. 고장 난 reload 뒤에 루프가 멈췄습니다: ${JSON.stringify(st.exits)}`);
		const framesAfterBroken = st.frames;
		st = await until(pg, lines, (s) => s.frames > framesAfterBroken + 10, "13d. 고장 난 reload 뒤에도 루프가 돈다");
		const shotBroken = await shot(pg, "smoke_mruby_reload_broken.png");

		const r2 = await pg.evaluate((src) => window.__game.reload({ "scripts/ruby/main.rb": src }), drawing("fixed", 0, 160, 0));
		expect(r2 === true, `13d. 고친 파일의 reload() 가 true 가 아닙니다: ${r2}`);
		st = await until(pg, lines, (s) => s.out.includes("fixed:render"), "13d. 고친 Ruby 스크립트가 다시 그린다");
		expect(st.out.includes("fixed:init"), "13d. 고친 스크립트의 init 이 돌지 않았습니다");
		expect(st.err.some((l) => l.includes("HotReload: reloaded (web)")), "13d. reload 성공 줄이 없습니다");
		await pg.waitForTimeout(300);
		const shotFixed = await shot(pg, "smoke_mruby_reload_fixed.png");

		const redGood = countColor(shotGood, RED);
		if (redGood === null) {
			console.log("web_smoke: 13d. 화면 대조 건너뜀 (python3 과 PIL 이 필요합니다)");
		} else {
			const redBroken = countColor(shotBroken, RED);
			const greenFixed = countColor(shotFixed, GREEN);
			const redFixed = countColor(shotFixed, RED);
			console.log(`web_smoke: 13d. 화면 red(good)=${redGood} red(broken)=${redBroken} green(fixed)=${greenFixed} red(fixed)=${redFixed} (칸 ${CELLS})`);
			expect(redGood > CELLS * 0.5, "13d. 첫 Ruby 스크립트의 그림이 canvas 에 없습니다");
			expect(redBroken < CELLS * 0.01, "13d. 고장 난 reload 뒤에도 이전 그림이 남았습니다 (스크립트가 멈추지 않았다)");
			expect(greenFixed > CELLS * 0.5 && redFixed < CELLS * 0.01, "13d. 고친 reload 뒤에 게임이 다시 그리지 않습니다");
		}

		await pg.evaluate(() => window.__game.quit());
		st = await until(pg, lines, (s) => s.exits.length > 0, "13d. quit 뒤 onExit");
		expect(st.exits[0] === 0, `13d. quit 뒤 onExit 코드가 0 이 아닙니다: ${st.exits[0]}`);
		expect(jsErrors(lines).length === 0, `13d. JS 쪽 오류: ${jsErrors(lines)[0]}`);
		console.log(`web_smoke: 13d. reload(고장)=false 와 "${BLOCK[0]}" 외 ${BLOCK.length - 1} 줄, 루프는 돈다. reload(고침)=true, 다시 그린다`);
		sameAsNative({ "scripts/ruby/main.rb": BROKEN }, BLOCK, "13d. (고장 난 파일로 시작)");
		await pg.close();
	}
}

let allOk = true;
try {
	// ---- 알데바란 타이틀 ----
	const page = await context.newPage();
	const lines = [];
	attachConsole(page, lines);

	const query = new URLSearchParams();
	query.append("env", "INITIAL2D_SCREENSHOT=/project/shot.bmp");
	query.append("env", "INITIAL2D_SCREENSHOT_FRAME=20");
	query.append("env", "INITIAL2D_NO_RTP=1");
	await page.goto(`${base}/?${query.toString()}`);
	await page.click("#run");

	await waitFor(lines, (l) => l.includes("Initial2D web: renderer="), "엔진 시작 줄");
	const rendererLine = lines.find((l) => l.includes("Initial2D web: renderer="));
	console.log("web_smoke: " + rendererLine);

	const shotExists = async () => page.evaluate(() => {
		const h = window.__initial2d;
		try { return !!(h && h.module.FS.analyzePath("/project/shot.bmp").exists); } catch (e) { return false; }
	});
	{
		const start = Date.now();
		while (!(await shotExists())) {
			const bad = lines.find((l) => BAD.test(l));
			if (bad) fail(`콘솔 오류: ${bad}`);
			if (Date.now() - start > TIMEOUT) fail("20 프레임 캡처가 MEMFS 에 생기지 않았습니다 (루프가 돌지 않는다)");
			await new Promise((r) => setTimeout(r, 100));
		}
	}
	const bmp = await page.evaluate(() => Array.from(window.__initial2d.module.FS.readFile("/project/shot.bmp")));
	fs.mkdirSync(path.dirname(OUT_BMP), { recursive: true });
	fs.writeFileSync(OUT_BMP, Buffer.from(bmp));
	console.log(`web_smoke: frame 20 -> ${OUT_BMP} (${bmp.length} bytes)`);

	// 타이틀이 다 그려지도록 잠깐 더 돌린 뒤 canvas 를 찍는다
	await page.waitForTimeout(1500);
	await page.locator("#canvas").screenshot({ path: OUT_PNG });
	console.log(`web_smoke: canvas -> ${OUT_PNG}`);

	// 골든 대조 (선택). 네이티브 검수와 같은 방식: 논리 해상도로 맞춘 뒤 픽셀 차이 비율
	if (GOLDEN) {
		const d = pixelDiff(OUT_BMP, GOLDEN);
		if (d === null) {
			console.log("web_smoke: 골든 대조 건너뜀 (python3 과 PIL 이 필요합니다)");
		} else {
			console.log(`web_smoke: golden ${path.relative(repo, GOLDEN)} ${d.line}`);
			// 렌더러(WebGL 과 소프트웨어)가 다를 수 있어 네이티브 골든보다 느슨하다.
			// 화면이 비었거나 다른 씬이면 절반 넘게 다르다.
			if (!(d.ratio < 0.25)) {
				allOk = false;
				console.error(`web_smoke: FAIL 골든과 ${(d.ratio * 100).toFixed(1)}% 다릅니다 (허용 25%)`);
			}
		}
	}

	// 5. 키보드: canvas 가 포커스를 가진 채 아래 화살표 + Enter -> "조작 방법" 설명 창
	await page.evaluate(() => document.getElementById("canvas").focus());
	await page.keyboard.press("ArrowDown");
	await page.waitForTimeout(250);
	await page.keyboard.press("Enter");
	await page.waitForTimeout(1200);
	await page.locator("#canvas").screenshot({ path: OUT_HELP_PNG });
	{
		const d = pixelDiff(OUT_PNG, OUT_HELP_PNG);
		if (d === null) {
			console.log("web_smoke: 키보드 확인 건너뜀 (python3 과 PIL 이 필요합니다)");
		} else {
			console.log(`web_smoke: keyboard ${d.line} -> ${OUT_HELP_PNG}`);
			if (!(d.ratio > 0.05)) {
				allOk = false;
				console.error("web_smoke: FAIL 키보드 입력이 게임에 닿지 않습니다 (설명 창이 뜨지 않았다)");
			}
		}
	}

	// 6. export: reload 와 quit
	const reloaded = await page.evaluate(() => window.__initial2d.reload());
	expect(reloaded === true, `reload() 가 true 가 아닙니다: ${reloaded}`);
	await waitFor(lines, (l) => l.includes("HotReload: reloaded (web)"), "reload 로그");
	await page.waitForTimeout(500);
	await page.evaluate(() => window.__initial2d.quit());
	await waitFor(lines, (l) => l.includes("Initial2D web: main loop stopped"), "quit 로그");
	console.log("web_smoke: reload() 와 quit() 동작");
	await page.close();

	// ---- 7. 설정 객체가 Lua 의 os.getenv 까지 가는가 (파일 한 장짜리 프로젝트) ----
	const page2 = await context.newPage();
	const lines2 = [];
	attachConsole(page2, lines2);
	await page2.goto(`${base}/`);
	await page2.evaluate(async () => {
		const { bootInitial2D } = await import("./initial2d-loader.js");
		const main = [
			'print("smoke env=" .. tostring(os.getenv("INITIAL2D_SMOKE")) .. " scene=" .. tostring(os.getenv("INITIAL2D_SCENE")))',
			"function Initialize() end",
			"function Update(elapsed) end",
			"function Render() end",
			"function Destroy() end",
		].join("\n");
		window.__initial2d = await bootInitial2D({
			canvas: document.getElementById("canvas"),
			files: { "scripts/lua/main.lua": main },
			env: { INITIAL2D_SMOKE: "42", INITIAL2D_EXIT_AFTER: 5 },
		});
	});
	await waitFor(lines2, (l) => l.includes("smoke env=42 scene=nil"), "os.getenv 확인 줄");
	await waitFor(lines2, (l) => l.includes("Initial2D web: main loop stopped"), "INITIAL2D_EXIT_AFTER 종료");
	console.log("web_smoke: os.getenv 가 설정 객체를 본다, INITIAL2D_EXIT_AFTER 로 끝난다");
	await page2.close();

	await errorCases();
	if (LUA_ONLY) {
		console.log("web_smoke: 12~13 (mruby) 건너뜀 (--lua-only)");
	} else {
		await mrubyCases();
	}
} finally {
	await browser.close();
	server.close();
}

if (!allOk) process.exit(1);
console.log("web_smoke: PASS");
