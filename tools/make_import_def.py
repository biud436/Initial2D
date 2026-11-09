#!/usr/bin/env python3
"""Windows DLL(PE32)의 내보내기 목록을 .def 파일로 쓴다.

Initial2D.vcxproj 는 가져오기 라이브러리(.lib)가 저장소에 없는 DLL 을 링크할 때, 이 .def 로 빌드 중에
lib.exe /def 를 돌려 .lib 를 만든다 (SDL2.dll, libpng16-16.dll). DLL 을 바꾸면 .def 도 다시 만든다.

  python3 tools/make_import_def.py SDL2.dll external/SDL2/SDL2.def
  python3 tools/make_import_def.py libpng16-16.dll external/libpng/libpng16-16.def
"""
import struct
import sys
from pathlib import Path


def pe_exports(data: bytes):
    """(machine, 내보낸 이름 목록). PE32(x86) 만 받는다."""
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        raise ValueError("not a PE file")
    machine, sections = struct.unpack_from("<HH", data, pe + 4)
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    optional = pe + 24
    if struct.unpack_from("<H", data, optional)[0] != 0x10B:
        raise ValueError("not PE32 (x86)")
    export_rva = struct.unpack_from("<I", data, optional + 96)[0]
    table = []
    for i in range(sections):
        s = optional + optional_size + 40 * i
        vsize, va, rawsize, rawptr = struct.unpack_from("<IIII", data, s + 8)
        table.append((va, max(vsize, rawsize), rawptr))

    def offset(rva):
        for va, size, raw in table:
            if va <= rva < va + size:
                return raw + rva - va
        raise ValueError(f"rva {rva:#x} outside sections")

    directory = offset(export_rva)
    names_count, _, names_rva = struct.unpack_from("<III", data, directory + 24)
    names = []
    for i in range(names_count):
        start = offset(struct.unpack_from("<I", data, offset(names_rva) + 4 * i)[0])
        names.append(data[start:data.index(b"\0", start)].decode("ascii"))
    return machine, names


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[-2].strip(), file=sys.stderr)
        return 2
    dll, out = Path(sys.argv[1]), Path(sys.argv[2])
    machine, names = pe_exports(dll.read_bytes())
    if machine != 0x14C:
        print(f"{dll}: machine {machine:#x}, expected x86 (0x14c)", file=sys.stderr)
        return 1
    lines = [
        f"; Export list of {dll.name} (x86), written by tools/make_import_def.py.",
        "; Initial2D.vcxproj runs lib.exe /def on it to make the import library.",
        f"LIBRARY {dll.stem}",
        "EXPORTS",
    ] + [f"    {name}" for name in names]
    out.write_text("\n".join(lines) + "\n", encoding="ascii")
    print(f"wrote {out} ({len(names)} exports)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
