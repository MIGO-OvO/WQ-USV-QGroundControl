"""Link the built QGC application with an isolated offline verification entry.

The application modules, resources, native confirmation and cockpit are the
production build. Only the entry adds settings isolation, scheduled checks and
a simulated vehicle whose command methods are counters. No real link is opened.
"""
import argparse
import json
import os
import re
import subprocess
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def ninja_block(source, pattern):
    match = re.search(pattern + r"\n((?:  [^\n]*\n)+)", source, re.M)
    if not match:
        raise RuntimeError(f"Build rule missing: {pattern}")
    values = dict(re.findall(r"^  (\w+) = (.*)$", match.group(1), re.M))
    return match, values


def pe_imports(path):
    """Read static DLL imports without adding a verification dependency."""
    data = path.read_bytes()
    pe = struct.unpack_from("<I", data, 60)[0]
    count = struct.unpack_from("<H", data, pe + 6)[0]
    optional, size = pe + 24, struct.unpack_from("<H", data, pe + 20)[0]
    sections = [struct.unpack_from("<IIII", data, optional + size + i * 40 + 8) for i in range(count)]

    def offset(rva):
        for virtual_size, address, raw_size, pointer in sections:
            if address <= rva < address + max(virtual_size, raw_size):
                return pointer + rva - address
        return rva

    directory = optional + (112 if struct.unpack_from("<H", data, optional)[0] == 0x20B else 96)
    rva = struct.unpack_from("<I", data, directory + 8)[0]
    names = []
    if rva:
        descriptor = offset(rva)
        while any(data[descriptor:descriptor + 20]):
            start = offset(struct.unpack_from("<I", data, descriptor + 12)[0])
            names.append(data[start:data.index(0, start)].decode("ascii"))
            descriptor += 20
    return names


def stage_runtime(executable):
    # Windows Store child processes use packaged DLL search paths and ignore
    # PATH at startup. Stage only missing imports beside the verification exe.
    folders = [executable.parent, Path("C:/Qt/6.10.1/msvc2022_64/bin"), Path("D:/gstreamer/1.0/msvc_x86_64/bin"), Path(os.environ["SystemRoot"]) / "System32"]
    pending, visited = [executable], set()
    while pending:
        library = pending.pop()
        if library.name.lower() in visited:
            continue
        visited.add(library.name.lower())
        for name in pe_imports(library):
            if name.lower().startswith(("api-ms-", "ext-ms-")):
                continue
            source = next((folder / name for folder in folders if (folder / name).exists()), None)
            if source is None:
                raise RuntimeError(f"Missing runtime DLL: {name} (required by {library.name})")
            if source.parent != folders[-1] and source.parent != executable.parent:
                target = executable.parent / name
                shutil.copy2(source, target)
                source = target
            pending.append(source)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=Path, default=ROOT / "build/workflow-qt6101")
    parser.add_argument("--output", type=Path, default=ROOT / "build/cockpit-qa-20261014")
    parser.add_argument("--reuse-binary", action="store_true", help="Only rerun an already-linked verification executable")
    parser.add_argument("--renderer", choices=("software", "rhi"), default="software")
    parser.add_argument("--platform", choices=("offscreen", "windows"), default="offscreen")
    parser.add_argument("--sdk-runtime", action="store_true", help="Opt into SDK paths; default verifies only the deployed runtime")
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    evidence_file = output / "native-boot-evidence.json"
    evidence_file.unlink(missing_ok=True)
    cache = (build / "CMakeCache.txt").read_text(encoding="utf-8")
    configuration = re.search(r"^CMAKE_BUILD_TYPE:STRING=(.+)$", cache, re.M).group(1)
    ninja = (build / "build.ninja").read_text(encoding="utf-8")
    _, compile_values = ninja_block(ninja, r"^build CMakeFiles\\QGroundControl\.dir\\src\\main\.cc\.obj: [^\n]+")
    link, link_values = ninja_block(ninja, rf"^build {re.escape(configuration)}\\QGroundControl\.exe: [^\n]+")
    # MSVC's localized /showIncludes prefix can make this generated file mixed-encoding.
    rule = (build / "CMakeFiles/rules.ninja").read_text(encoding="utf-8", errors="replace")
    compiler = re.search(r"command = .*?([A-Za-z]:[^\n]+?\\cl\.exe) ", rule).group(1)
    linker = str(Path(compiler).with_name("link.exe"))
    entry = (ROOT / "src/main.cc").read_text(encoding="utf-8")
    assert entry.count("int main(") == 1 and entry.count("    app.init();") == 1
    entry = entry.replace("int main(", "int qgcBootEntry(", 1).replace("    app.init();", "    app.init();\n    QTimer::singleShot(2000, &app, verifyNativeCockpit);", 1)
    entry = entry.replace("    QGCLogging::installHandler();", "    QGCLogging::installHandler();\n    installNativeMessageCapture();", 1)
    source = (ROOT / "custom/tests/NativeCockpitBoot.cc").read_text(encoding="utf-8").replace("// APPLICATION_ENTRY", entry)
    cpp, obj, executable = output / "native-boot.cpp", output / "native-boot.obj", build / configuration / "QGCCockpitBoot.exe"
    cpp.write_text(source, encoding="utf-8")
    compile_rsp = output / "native-compile.rsp"
    compile_rsp.write_text(" ".join(compile_values.get(key, "") for key in ("DEFINES", "INCLUDES", "FLAGS")) + f' /I"{ROOT / "custom/src"}" /nologo /TP /Fo"{obj}" /Fd"{output / "native-boot.pdb"}" /FS -c "{cpp}"', encoding="utf-8")
    inputs = link.group(0).split("\n", 1)[0].split(": ", 1)[1].split(" ", 1)[1].split(" | ", 1)[0]
    inputs = inputs.replace(r"CMakeFiles\QGroundControl.dir\src\main.cc.obj", f'"{obj}"')
    link_rsp = output / "native-link.rsp"
    link_rsp.write_text(inputs + " " + link_values.get("LINK_PATH", "") + " " + link_values["LINK_LIBRARIES"] + f' /nologo /out:"{executable}" /pdb:"{output / "native-link.pdb"}" ' + link_values.get("LINK_FLAGS", ""), encoding="utf-8")
    if not args.reuse_binary:
        subprocess.run([compiler, f"@{compile_rsp}"], cwd=build, check=True)
        subprocess.run([linker, f"@{link_rsp}"], cwd=build, check=True)
    if args.sdk_runtime:
        stage_runtime(executable)
    env = os.environ.copy()
    env.update(USV_QA_OUTPUT=output.as_posix(), USV_QA_MOCK_FILE=(ROOT / "custom/tests/NativeGuidedMock.qml").as_posix(), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", QT_QPA_FONTDIR="C:/Windows/Fonts", QML_DISABLE_DISK_CACHE="1", QML_IMPORT_PATH="C:/Qt/6.10.1/msvc2022_64/qml", QT_PLUGIN_PATH="C:/Qt/6.10.1/msvc2022_64/plugins", PATH=f"{build / configuration};C:\\Qt\\6.10.1\\msvc2022_64\\bin;D:\\gstreamer\\1.0\\msvc_x86_64\\bin;" + env["PATH"])
    env["QT_QPA_PLATFORM"] = args.platform
    if args.renderer == "rhi":
        env.pop("QT_QUICK_BACKEND", None)
    if not args.sdk_runtime:
        for key in ("QT_PLUGIN_PATH", "QT_QPA_PLATFORM_PLUGIN_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH", "QT_QML_ROOT_PATH", "QT_QPA_FONTDIR"):
            env.pop(key, None)
        system_root = os.environ["SystemRoot"]
        env["PATH"] = os.pathsep.join((str(executable.parent), str(Path(system_root) / "System32"), system_root))
    with (output / "native-boot.log").open("w", encoding="utf-8") as log:
        result = subprocess.run([str(executable), "--allow-multiple", "--log-output", "--no-windows-assert-ui"], cwd=build, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=45)
    evidence = json.loads(evidence_file.read_text(encoding="utf-8")) if evidence_file.exists() else {}
    qml_log = output / "native-qml.log"
    messages = qml_log.read_text(encoding="utf-8").splitlines() if qml_log.exists() else []
    evidence["runtimeErrors"] = [line for line in messages if any(marker in line for marker in ("TypeError", "ReferenceError", "Unable to assign", "Binding loop", "Error:", "is not a type", "Cannot assign", "failed to load component"))]
    evidence["passed"] = bool(evidence.get("passed")) and not evidence["runtimeErrors"]
    evidence["runtimeMode"] = "sdk" if args.sdk_runtime else "deployed"
    evidence_file.write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    if result.returncode or not evidence.get("passed"):
        raise RuntimeError(f"Native boot failed ({result.returncode}): see {output / 'native-boot.log'}")
    print(f"PASS: full QGC resource integration; {len(evidence['checks'])} native checks; Qt {evidence['qt']}")


if __name__ == "__main__":
    main()
