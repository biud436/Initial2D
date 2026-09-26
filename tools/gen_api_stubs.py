#!/usr/bin/env python3
"""스크립트 API 명세에서 에디터용 스텁 두 장을 만든다 (R2, docs/plans/r2-api-stubs.md).

명세 resources/api/initial2d-api.json 은 손으로 유지하고, 바인딩과의 대조는 엔진 안의
단위 테스트(tests/lua/cases/api_surface_test.lua, tests/ruby/cases/api_surface_test.rb)가 한다.
이 도구는 그 명세를 읽어 에디터 자동완성용 스텁을 쓴다.

  resources/api/initial2d.lua   EmmyLua / LuaLS 주석 (---@param, ---@return, ---@class)
  resources/api/initial2d.rb    Ruby 스텁과 YARD 주석 (# @param [Integer] x)

사용법:
  python3 tools/gen_api_stubs.py           # 스텁 두 장을 다시 쓴다
  python3 tools/gen_api_stubs.py --check   # 디스크의 스텁이 명세와 다르면 종료 코드 1 (run_all.sh 가 쓴다)

표준 라이브러리만 쓰고, 같은 명세에서는 언제나 같은 바이트를 만든다 (정렬하지 않고 명세의 순서를 따른다).
명세가 규칙(아래 validate)을 어기면 스텁을 쓰지 않고 종료 코드 1 로 끝낸다.
"""

import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_JSON = os.path.join(REPO, "resources", "api", "initial2d-api.json")
LUA_STUB = os.path.join(REPO, "resources", "api", "initial2d.lua")
RUBY_STUB = os.path.join(REPO, "resources", "api", "initial2d.rb")

RUBY_KINDS = ("method", "getter", "setter", "predicate", "module_function")

TOP_KEYS = ["version", "engine", "generatedFrom", "types", "modules", "classes", "constants", "sceneContract"]
MODULE_KEYS = {"name", "lua", "ruby", "doc", "functions"}
CLASS_KEYS = {"name", "lua", "ruby", "doc", "luaStyle", "constructors", "methods"}
FUNCTION_KEYS = {"lua", "ruby", "params", "luaParams", "rubyParams", "overloads", "returns",
                 "luaReturns", "rubyReturns", "doc", "rubyKind", "alias", "aliasOf", "prelude"}
CONSTRUCTOR_KEYS = {"lua", "ruby", "params", "returns", "luaReturns", "rubyReturns", "doc", "prelude"}
PARAM_KEYS = {"name", "type", "optional", "default", "variadic", "luaType", "rubyType", "doc"}
CONSTANT_KEYS = {"module", "lua", "ruby", "doc", "names", "values"}
SCENE_KEYS = {"name", "lua", "ruby", "params", "doc", "luaRequired"}

# 문서 표기 규칙 (CLAUDE.md): 가운뎃점과 em-dash 를 쓰지 않는다
FORBIDDEN_CHARS = ("\u00b7", "\u2014")


# ----------------------------------------------------------------------
# 검증
# ----------------------------------------------------------------------

class Checker:
    def __init__(self, api):
        self.api = api
        self.errors = []
        self.types = set(api.get("types", []))

    def err(self, where, message):
        self.errors.append(f"{where}: {message}")

    def type_expr(self, where, expr):
        """number, integer|nil, string[] 같은 타입 식을 확인한다."""
        if not isinstance(expr, str) or not expr:
            self.err(where, f"타입 식이 문자열이 아니다: {expr!r}")
            return
        for alt in expr.split("|"):
            base = alt[:-2] if alt.endswith("[]") else alt
            if base not in self.types:
                self.err(where, f"모르는 타입 {base!r} (types 에 없다)")

    def returns(self, where, value, allow_list):
        if isinstance(value, list):
            if not allow_list:
                self.err(where, "여러 값 반환(배열)은 Lua 쪽에서만 쓴다 (luaReturns, 또는 ruby 가 null 인 항목)")
            if not value:
                self.err(where, "빈 반환 목록")
            for i, t in enumerate(value):
                self.type_expr(f"{where}[{i}]", t)
        else:
            self.type_expr(where, value)

    def doc(self, where, text):
        if not isinstance(text, str) or not text.strip():
            self.err(where, "doc 이 비었다 (한 줄 설명이 필요하다)")
            return
        if "\n" in text:
            self.err(where, "doc 은 한 줄이어야 한다")
        for ch in FORBIDDEN_CHARS:
            if ch in text:
                self.err(where, f"doc 에 쓰지 않는 문자 {ch!r} 가 있다")

    def keys(self, where, obj, allowed):
        if not isinstance(obj, dict):
            self.err(where, "객체가 아니다")
            return False
        for k in obj:
            if k not in allowed:
                self.err(where, f"모르는 키 {k!r}")
        return True

    def params(self, where, params):
        if not isinstance(params, list):
            self.err(where, "params 는 배열이어야 한다")
            return
        seen_optional = False
        names = set()
        for i, p in enumerate(params):
            w = f"{where}[{i}]"
            if not self.keys(w, p, PARAM_KEYS):
                continue
            name = p.get("name")
            if not isinstance(name, str) or not name:
                self.err(w, "name 이 없다")
            elif name in names:
                self.err(w, f"같은 이름의 인자 {name!r}")
            names.add(name)
            self.type_expr(w + ".type", p.get("type"))
            for k in ("luaType", "rubyType"):
                if k in p:
                    self.type_expr(f"{w}.{k}", p[k])
            if "doc" in p:
                self.doc(w + ".doc", p["doc"])
            if "default" in p and not p.get("optional"):
                self.err(w, "default 는 optional 인자에만 쓴다")
            if p.get("variadic") and i != len(params) - 1:
                self.err(w, "variadic 은 마지막 인자만")
            if p.get("optional"):
                seen_optional = True
            elif seen_optional and not p.get("variadic"):
                self.err(w, "필수 인자가 선택 인자 뒤에 있다")

    def function(self, where, f, owner_kind):
        allowed = CONSTRUCTOR_KEYS if owner_kind == "constructor" else FUNCTION_KEYS
        if not self.keys(where, f, allowed):
            return
        for k in ("lua", "ruby", "params", "returns", "doc"):
            if k not in f:
                self.err(where, f"{k} 가 없다")
        lua, ruby = f.get("lua"), f.get("ruby")
        if lua is None and ruby is None:
            self.err(where, "lua 와 ruby 가 둘 다 null 이다")
        self.params(where + ".params", f.get("params", []))
        for k in ("luaParams", "rubyParams"):
            if k in f:
                self.params(f"{where}.{k}", f[k])
        for i, ov in enumerate(f.get("overloads", [])):
            self.params(f"{where}.overloads[{i}]", ov)
        if "returns" in f:
            # ruby 쪽이 따로 적혀 있거나 ruby 가 없으면 returns 가 Lua 전용이라 배열도 된다
            self.returns(where + ".returns", f["returns"], ruby is None or "rubyReturns" in f)
        if "luaReturns" in f:
            self.returns(where + ".luaReturns", f["luaReturns"], True)
        if "rubyReturns" in f:
            self.returns(where + ".rubyReturns", f["rubyReturns"], False)
        self.doc(where + ".doc", f.get("doc"))

        if owner_kind == "constructor":
            return
        kind = f.get("rubyKind")
        if ruby is None:
            if kind is not None:
                self.err(where, "ruby 가 null 인데 rubyKind 가 있다")
        else:
            if kind not in RUBY_KINDS:
                self.err(where, f"rubyKind 는 {', '.join(RUBY_KINDS)} 중 하나 ({kind!r})")
            if ruby.endswith("?") != (kind == "predicate"):
                self.err(where, f"{ruby}: ? 로 끝나는 이름과 predicate 는 짝이다")
            if ruby.endswith("=") != (kind == "setter"):
                self.err(where, f"{ruby}: = 로 끝나는 이름과 setter 는 짝이다")
            rparams = f.get("rubyParams", f.get("params", []))
            if kind == "getter" and any(not p.get("optional") for p in rparams):
                self.err(where, f"{ruby}: getter 는 필수 인자가 없어야 한다 (테스트가 인자 없이 부른다)")
            if kind == "setter" and len(rparams) != 1:
                self.err(where, f"{ruby}: setter 는 인자가 하나다")
        if f.get("alias") and not f.get("aliasOf"):
            self.err(where, "alias 에는 aliasOf 가 필요하다")

    def names_unique(self, where, entries):
        for lang in ("lua", "ruby"):
            seen = set()
            for f in entries:
                name = f.get(lang)
                if name is None:
                    continue
                if name in seen:
                    self.err(where, f"{lang} 이름 {name!r} 가 두 번 나온다")
                seen.add(name)

    def alias_targets(self, where, entries):
        for f in entries:
            target = f.get("aliasOf")
            if target is None:
                continue
            if not any(g is not f and (g.get("lua") == target or g.get("ruby") == target) for g in entries):
                self.err(where, f"aliasOf {target!r} 인 항목이 같은 모듈에 없다")

    def run(self):
        api = self.api
        if list(api.keys()) != TOP_KEYS:
            self.err("최상위", f"키와 순서는 {TOP_KEYS} 이어야 한다 (실제 {list(api.keys())})")
        if api.get("version") != 1:
            self.err("version", "이 도구는 version 1 만 안다")
        for t in ("number", "integer", "string", "boolean", "nil", "any"):
            if t not in self.types:
                self.err("types", f"기본 타입 {t!r} 가 없다")

        module_names = set()
        for mi, m in enumerate(api.get("modules", [])):
            w = f"modules[{mi}]"
            if not self.keys(w, m, MODULE_KEYS):
                continue
            w = f"modules.{m.get('name')}"
            if m.get("name") in module_names:
                self.err(w, "같은 이름의 모듈")
            module_names.add(m.get("name"))
            self.doc(w + ".doc", m.get("doc"))
            functions = m.get("functions", [])
            for fi, f in enumerate(functions):
                self.function(f"{w}.functions[{fi}]", f, "function")
            self.names_unique(w, functions)
            self.alias_targets(w, functions)

        # Lua 에서 모듈 이름이 null 인 함수는 전역이다. 전역끼리도 겹치면 안 된다
        seen_globals = set()
        for m in api.get("modules", []):
            if m.get("lua") is not None:
                continue
            for f in m.get("functions", []):
                if f.get("lua") in seen_globals:
                    self.err(f"modules.{m.get('name')}", f"Lua 전역 {f.get('lua')!r} 가 두 모듈에 있다")
                if f.get("lua") is not None:
                    seen_globals.add(f.get("lua"))

        for ci, c in enumerate(api.get("classes", [])):
            w = f"classes[{ci}]"
            if not self.keys(w, c, CLASS_KEYS):
                continue
            w = f"classes.{c.get('name')}"
            if c.get("name") not in self.types:
                self.err(w, "클래스 이름이 types 에 없다")
            if c.get("luaStyle") not in (None, "handle"):
                self.err(w, "luaStyle 은 handle 만 안다")
            self.doc(w + ".doc", c.get("doc"))
            for ki, k in enumerate(c.get("constructors", [])):
                kw = f"{w}.constructors[{ki}]"
                self.function(kw, k, "constructor")
                for lang in ("lua", "ruby"):
                    name = k.get(lang)
                    owner = c.get(lang)
                    if name is not None and (owner is None or not name.startswith(owner + ".")):
                        self.err(kw, f"{lang} 생성자 이름은 '{owner}.이름' 꼴이어야 한다 ({name!r})")
            methods = c.get("methods", [])
            for fi, f in enumerate(methods):
                self.function(f"{w}.methods[{fi}]", f, "method")
                if f.get("rubyKind") == "module_function":
                    self.err(f"{w}.methods[{fi}]", "클래스 메서드에는 module_function 을 쓰지 않는다")
            self.names_unique(w, methods)
            self.names_unique(w + ".constructors", c.get("constructors", []))

        for ci, c in enumerate(api.get("constants", [])):
            w = f"constants[{ci}]"
            if not self.keys(w, c, CONSTANT_KEYS):
                continue
            self.doc(w + ".doc", c.get("doc"))
            names = c.get("names", [])
            values = c.get("values", {})
            if len(set(names)) != len(names):
                self.err(w, "names 에 같은 이름이 두 번 있다")
            if list(values.keys()) != list(names):
                self.err(w, "values 의 키는 names 와 같은 순서, 같은 목록이어야 한다")
            for n, v in values.items():
                if not isinstance(v, int) or isinstance(v, bool):
                    self.err(w, f"{n} 의 값이 정수가 아니다")

        for si, s in enumerate(api.get("sceneContract", [])):
            w = f"sceneContract[{si}]"
            if not self.keys(w, s, SCENE_KEYS):
                continue
            self.params(w + ".params", s.get("params", []))
            self.doc(w + ".doc", s.get("doc"))
        return self.errors


# ----------------------------------------------------------------------
# 공용 도우미
# ----------------------------------------------------------------------

def lua_params(f):
    return f.get("luaParams", f.get("params", []))


def ruby_params(f):
    return f.get("rubyParams", f.get("params", []))


def lua_returns(f):
    return f.get("luaReturns", f.get("returns", "nil"))


def ruby_returns(f):
    return f.get("rubyReturns", f.get("returns", "nil"))


def default_text(value):
    """기본값을 사람이 읽을 글로 (Lua 주석용)."""
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    return json.dumps(value, ensure_ascii=False)


# ----------------------------------------------------------------------
# Lua 스텁 (EmmyLua / LuaLS)
# ----------------------------------------------------------------------

def lua_type(expr, handles):
    out = []
    for alt in expr.split("|"):
        array = alt.endswith("[]")
        base = alt[:-2] if array else alt
        if base in handles:
            t = base + "Handle"
        elif base == "array":
            t = "table"
        elif base == "symbol":
            t = "string"
        else:
            t = base
        out.append(t + ("[]" if array else ""))
    return "|".join(out)


def lua_doc_lines(f, params, handles, handle_param=None):
    lines = ["---" + f["doc"]]
    if handle_param is not None:
        lines.append(f"---@param handle {handle_param}")
    for p in params:
        t = lua_type(p.get("luaType", p["type"]), handles)
        if p.get("variadic"):
            lines.append(f"---@param ... {t}" + (" " + p["doc"] if "doc" in p else ""))
            continue
        name = p["name"] + ("?" if p.get("optional") else "")
        desc = []
        if "doc" in p:
            desc.append(p["doc"])
        if "default" in p:
            desc.append("기본값 " + default_text(p["default"]))
        lines.append(f"---@param {name} {t}" + (" " + ", ".join(desc) if desc else ""))
    for ov in f.get("overloads", []):
        args = []
        if handle_param is not None:
            args.append(f"handle: {handle_param}")
        for p in ov:
            args.append(f"{p['name']}: {lua_type(p.get('luaType', p['type']), handles)}")
        lines.append("---@overload fun(" + ", ".join(args) + ")")
    ret = lua_returns(f)
    if isinstance(ret, list):
        for t in ret:
            lines.append("---@return " + lua_type(t, handles))
    elif ret != "nil":
        lines.append("---@return " + lua_type(ret, handles))
    return lines


def lua_signature(params, handle=False):
    names = (["handle"] if handle else []) + [("..." if p.get("variadic") else p["name"]) for p in params]
    return "(" + ", ".join(names) + ")"


def render_lua(api):
    handles = [c["name"] for c in api["classes"] if c.get("luaStyle") == "handle"]
    out = [
        "---@meta",
        "-- Initial2D 스크립트 API 스텁 (Lua, EmmyLua / LuaLS 주석)",
        "-- tools/gen_api_stubs.py 가 resources/api/initial2d-api.json 에서 만든다. 손으로 고치지 않는다.",
        "-- 에디터 자동완성용이며 엔진이 읽지 않는다 (같은 이름은 엔진이 C++ 로 등록한다).",
        f"-- 명세 version {api['version']}",
        "--",
        "-- 씬 계약: 엔진이 부르는 전역 함수 (Lua 는 넷 다 정의해야 한다)",
    ]
    for s in api["sceneContract"]:
        if s.get("lua") is None:
            continue
        sig = "function " + s["lua"] + lua_signature(s.get("params", [])) + " end"
        out.append(f"--   {sig:<34} {s['doc']}")
    out.append("")

    for c in api["classes"]:
        if c.get("luaStyle") == "handle" and c.get("lua") is not None:
            out.append(f"---{c['name']} 의 숫자 핸들 ({c['lua']} 표의 함수에 첫 인자로 넘긴다)")
            out.append(f"---@alias {c['name']}Handle number")
            out.append("")

    for m in api["modules"]:
        fns = [f for f in m["functions"] if f.get("lua") is not None]
        if not fns:
            continue
        if m.get("lua") is None:
            out.append(f"-- {m['name']}: {m['doc']}")
            out.append("")
            for f in fns:
                params = lua_params(f)
                out.extend(lua_doc_lines(f, params, handles))
                out.append(f"function {f['lua']}{lua_signature(params)} end")
                out.append("")
        else:
            out.append("---" + m["doc"])
            out.append(f"---@class {m['lua']}")
            out.append(f"{m['lua']} = {{}}")
            out.append("")
            for f in fns:
                params = lua_params(f)
                out.extend(lua_doc_lines(f, params, handles))
                out.append(f"function {m['lua']}.{f['lua']}{lua_signature(params)} end")
                out.append("")

    for c in api["classes"]:
        if c.get("lua") is None:
            continue
        handle_type = c["name"] + "Handle" if c.get("luaStyle") == "handle" else None
        out.append("---" + c["doc"])
        out.append(f"---@class {c['lua']}")
        out.append(f"{c['lua']} = {{}}")
        out.append("")
        for k in c.get("constructors", []):
            if k.get("lua") is None:
                continue
            params = lua_params(k)
            out.extend(lua_doc_lines(k, params, handles))
            out.append(f"function {k['lua']}{lua_signature(params)} end")
            out.append("")
        for f in c.get("methods", []):
            if f.get("lua") is None:
                continue
            params = lua_params(f)
            out.extend(lua_doc_lines(f, params, handles, handle_type))
            out.append(f"function {c['lua']}.{f['lua']}{lua_signature(params, handle_type is not None)} end")
            out.append("")

    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + "\n"


# ----------------------------------------------------------------------
# Ruby 스텁 (YARD)
# ----------------------------------------------------------------------

RUBY_TYPE_NAMES = {
    "number": "Numeric", "integer": "Integer", "string": "String", "boolean": "Boolean",
    "table": "Hash", "array": "Array", "function": "Proc", "nil": "nil", "any": "Object",
    "symbol": "Symbol",
}

# 대문자로 시작하지만 Ruby 예약어라 상수 대입 구문에 그대로 못 쓰는 이름
RUBY_KEYWORD_CONSTANTS = ("BEGIN", "END")


def yard_type(expr):
    out = []
    for alt in expr.split("|"):
        array = alt.endswith("[]")
        base = alt[:-2] if array else alt
        name = RUBY_TYPE_NAMES.get(base, base)
        out.append(f"Array<{name}>" if array else name)
    return ", ".join(out)


def ruby_literal(value):
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    return json.dumps(value, ensure_ascii=False)


def ruby_signature(params):
    parts = []
    for p in params:
        if p.get("variadic"):
            parts.append("*" + p["name"].strip("."))
        elif p.get("optional"):
            parts.append(f"{p['name']} = {ruby_literal(p.get('default'))}")
        else:
            parts.append(p["name"])
    return "(" + ", ".join(parts) + ")" if parts else ""


def ruby_doc_lines(f, params, indent, is_initialize=False):
    lines = [indent + "# " + f["doc"]]
    for p in params:
        t = yard_type(p.get("rubyType", p["type"]))
        desc = []
        if "doc" in p:
            desc.append(p["doc"])
        if "default" in p:
            desc.append("기본값 " + ruby_literal(p["default"]))
        lines.append(f"{indent}# @param [{t}] {p['name']}" + (" " + ", ".join(desc) if desc else ""))
    for ov in f.get("overloads", []):
        name = f["ruby"].split(".")[-1]
        lines.append(f"{indent}# @overload {name}({', '.join(p['name'] for p in ov)})")
        for p in ov:
            desc = " " + p["doc"] if "doc" in p else ""
            lines.append(f"{indent}#   @param [{yard_type(p.get('rubyType', p['type']))}] {p['name']}{desc}")
    if not is_initialize:
        ret = ruby_returns(f)
        lines.append(f"{indent}# @return [{'void' if ret == 'nil' else yard_type(ret)}]")
    if f.get("alias"):
        lines.append(f"{indent}# @see {f['aliasOf']}")
    return lines


def render_ruby(api):
    out = [
        "# Initial2D 스크립트 API 스텁 (Ruby, YARD 주석)",
        "# tools/gen_api_stubs.py 가 resources/api/initial2d-api.json 에서 만든다. 손으로 고치지 않는다.",
        "# 에디터 자동완성용이며 엔진이 읽지 않는다 (같은 이름은 엔진이 C++ 와 프렐류드로 정의한다).",
        f"# 명세 version {api['version']}",
        "#",
        "# 씬 계약: 엔진이 부르는 최상위 메서드 (없는 것은 부르지 않는다)",
    ]
    for s in api["sceneContract"]:
        if s.get("ruby") is None:
            continue
        sig = "def " + s["ruby"] + ruby_signature(s.get("params", [])) + "; end"
        out.append(f"#   {sig:<30} {s['doc']}")
    out.append("")

    for m in api["modules"]:
        fns = [f for f in m["functions"] if f.get("ruby") is not None]
        if not fns or m.get("ruby") is None:
            continue
        out.append("# " + m["doc"])
        out.append(f"module {m['ruby']}")
        body = []
        for f in fns:
            params = ruby_params(f)
            body.extend(ruby_doc_lines(f, params, "  "))
            prefix = "" if f.get("rubyKind") == "module_function" else "self."
            body.append(f"  def {prefix}{f['ruby']}{ruby_signature(params)}; end")
            body.append("")
        while body and body[-1] == "":
            body.pop()
        out.extend(body)
        out.append("end")
        out.append("")

    for c in api["constants"]:
        if c.get("ruby") is None:
            continue
        out.append("# " + c["doc"])
        out.append(f"module {c['ruby']}")
        for n in c["names"]:
            # END 와 BEGIN 은 예약어라 `END = 35` 가 구문 오류다. self:: 를 붙이면 된다
            target = f"self::{n}" if n in RUBY_KEYWORD_CONSTANTS else n
            out.append(f"  {target} = {c['values'][n]}")
        out.append("end")
        out.append("")

    for c in api["classes"]:
        if c.get("ruby") is None:
            continue
        out.append("# " + c["doc"])
        out.append(f"class {c['ruby']}")
        body = []
        for k in c.get("constructors", []):
            if k.get("ruby") is None:
                continue
            params = ruby_params(k)
            name = k["ruby"].split(".", 1)[1]
            if name == "new":
                body.extend(ruby_doc_lines(k, params, "  ", is_initialize=True))
                body.append(f"  def initialize{ruby_signature(params)}; end")
            else:
                body.extend(ruby_doc_lines(k, params, "  "))
                body.append(f"  def self.{name}{ruby_signature(params)}; end")
            body.append("")
        for f in c.get("methods", []):
            if f.get("ruby") is None:
                continue
            params = ruby_params(f)
            body.extend(ruby_doc_lines(f, params, "  "))
            body.append(f"  def {f['ruby']}{ruby_signature(params)}; end")
            body.append("")
        while body and body[-1] == "":
            body.pop()
        out.extend(body)
        out.append("end")
        out.append("")

    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + "\n"


# ----------------------------------------------------------------------
# 진입점
# ----------------------------------------------------------------------

def load_api(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main(argv):
    check = "--check" in argv
    unknown = [a for a in argv if a != "--check"]
    if unknown:
        print(f"모르는 인자: {' '.join(unknown)}", file=sys.stderr)
        print(__doc__, file=sys.stderr)
        return 2

    try:
        api = load_api(API_JSON)
    except (OSError, ValueError) as e:
        print(f"명세를 읽지 못했다: {API_JSON}: {e}", file=sys.stderr)
        return 1

    errors = Checker(api).run()
    if errors:
        print(f"명세 규칙 위반 {len(errors)}건 ({os.path.relpath(API_JSON, REPO)}):", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1

    outputs = [(LUA_STUB, render_lua(api)), (RUBY_STUB, render_ruby(api))]

    if check:
        stale = []
        for path, text in outputs:
            try:
                with open(path, encoding="utf-8", newline="") as f:
                    current = f.read()
            except OSError:
                current = None
            if current != text:
                stale.append(os.path.relpath(path, REPO))
        if stale:
            print("스텁이 명세와 다르다: " + ", ".join(stale), file=sys.stderr)
            print("  python3 tools/gen_api_stubs.py 로 다시 만들고 함께 커밋한다", file=sys.stderr)
            return 1
        print("API 스텁 최신 (" + ", ".join(os.path.relpath(p, REPO) for p, _ in outputs) + ")")
        return 0

    for path, text in outputs:
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("썼다: " + os.path.relpath(path, REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
