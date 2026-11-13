"""Create a source-only handoff for a Mac; excludes local credentials and build output."""
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FOLDERS = [".github", "docs", "LyricsCarPlay", "LyricsCarPlay.xcodeproj", "LyricsCarPlayTests", "LyricsCarPlayUITests", "backend", "scripts"]


def package():
    selected = [ROOT / name for name in ["README.md", "LICENSE", ".gitignore", ".gitattributes", "CHANGELOG.md", "Config/App.xcconfig", "Config/Local.xcconfig.example"] if (ROOT / name).exists()]
    for folder in FOLDERS:
        for path in (ROOT / folder).rglob("*"):
            if path.is_file() and not any(part in {"__pycache__", "xcuserdata", ".DS_Store"} for part in path.parts) and path.suffix not in {".pyc", ".xcuserstate"}:
                selected.append(path)
    destination = ROOT / ".build/LyricsCarPlay-source.zip"
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(set(selected)):
            archive.write(path, path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(destination) as archive:
        assert "Config/Local.xcconfig" not in archive.namelist()
        assert all(not name.startswith((".git/", ".build/")) for name in archive.namelist())
        print(f"Created {destination.name}: {len(archive.namelist())} source files; no Git metadata, local settings or build products.")
    return destination


if __name__ == "__main__":
    print(package())
