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
//   6. reload() 와 quit() export 가 콘솔에 자기 줄을 남기는지 본다.
//   7. 두 번째 페이지: 파일 한 장짜리 main.lua 를 올려 os.getenv 가 설정 객체를 보는지 본다.
//   콘솔에 "Lua error", "abort(", "RuntimeError", 페이지 오류가 보이면 실패다.
import fs from "node:fs";
import http from "node:http";
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
	await page.evaluate(() => window.__initial2d.reload());
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
} finally {
	await browser.close();
	server.close();
}

if (!allOk) process.exit(1);
console.log("web_smoke: PASS");
