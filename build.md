# Building Petalia from Source

This project compiles directly from the command line using macOS developer tools (`swiftc` and `gcc`/`clang`). You do not need to open or configure Xcode to build the application.

---

## 📋 Requirements
- macOS 12 (Monterey) or later
- Command Line Tools. If you don't have them installed, run:
  ```bash
  xcode-select --install
  ```

---

## 🛠️ Build Commands

All builds are orchestrated via the `scripts/build.sh` script. Run them from the project's root directory:

### 1. Incremental Build (Default)
By default, the script compiles files incrementally. Only files you have modified (and their dependents) will be recompiled, saving compilation time.
```bash
./scripts/build.sh
```

### 2. Clean Build
To wipe the build cache (`.build-cache/`) and compile all files from scratch:
```bash
./scripts/build.sh --clean
```

### 3. Build for All Architectures (Universal Binary)
To build a universal binary for both Intel (`x86_64`) and Apple Silicon (`arm64`) architectures (defaults to your host machine's architecture):
```bash
./scripts/build.sh --all
```
*Note: You can combine this flag with clean: `./scripts/build.sh --all --clean`*

---

## 📁 Build Output

The successfully built application will be stored at:
```
build/Petalia.app
```

---

## ⚙️ How It Works (Incremental Compilation)
- The script uses the Swift compiler's native `-incremental` mode.
- Compilation metadata and object files (`.o`) are cached under `.build-cache/`.
- Changing a single file only recompiles that specific file, bringing compile times down from minutes to a few seconds.
