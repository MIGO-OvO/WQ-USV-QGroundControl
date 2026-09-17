"""Verify a built APK actually carries the USV override layer.

Compiling successfully is not proof that the custom layer shipped: on Android the
QML override, custom.qrc content and compiled translations are embedded in the
native library as Qt resources, so a link/packaging regression can produce a
working APK without any USV content.

Qt's resource generator stores the resource tree with UTF-16 names, so both
encodings are probed. Only leaf names are required, because rcc stores each path
component separately and only leaf names are guaranteed to be contiguous.
"""
import pathlib
import sys
import zipfile

# Leaf names, each tied to a distinct packaging path:
#   FlyViewCustomLayer.qml  -> QML override shipped for Android
#   USVSamplingDataView.qml -> custom.qrc / USV QML module content
#   usv_zh_CN.qm            -> compiled USV translations from custom/translations
REQUIRED = (
    "FlyViewCustomLayer.qml",
    "USVSamplingDataView.qml",
    "usv_zh_CN.qm",
)


def contains(payload, name):
    return name.encode("utf-16-le") in payload or name.encode("ascii") in payload


def main():
    apk = pathlib.Path(sys.argv[1])
    with zipfile.ZipFile(apk) as archive:
        libraries = [
            entry
            for entry in archive.namelist()
            if entry.startswith("lib/") and "/libQGroundControl" in entry and entry.endswith(".so")
        ]
        if not libraries:
            sys.exit(f"::error::No QGroundControl native library inside {apk.name}")

        missing = []
        for library in libraries:
            payload = archive.read(library)
            for name in REQUIRED:
                found = contains(payload, name)
                print(f"{library} :: {name} -> {'present' if found else 'MISSING'}")
                if not found:
                    missing.append(f"{library}::{name}")

    if missing:
        sys.exit("::error::USV resources absent from APK payload: " + ", ".join(missing))
    print(f"{apk.name}: USV payload present in {len(libraries)} native library/ies")


if __name__ == "__main__":
    main()
