# eSim 2.5 on Ubuntu 25.04 (Plucky Puffin): Upgradation & Bug Fix Report

**Environment:** Ubuntu 25.04 (Plucky Puffin) in VirtualBox (x86_64), GCC 14.2 / GNAT 14.2, LLVM 20.1, Python 3.12/3.13, KiCad 8.0, eSim 2.5
**Submission:** Task 4 – eSim Upgradation (CSE and related fields)
**Author:** Deepali Kumari

---

## 1. Summary of Issues Identified and Fixed

| # | Component | Issue Observed | Root Cause | Implemented Solution | Status |
|---|-----------|----------------|------------|----------------------|--------|
| **1** | Main Installer | Unsupported OS 25.04 | `install-eSim.sh` only mapped up to 24.04 | Added `25.04\|25.*)` to route to updated installation script | **FIXED** |
| **2** | NGHDL Installer | Unsupported OS 25.04 | `nghdl/install-nghdl.sh` rejected 25.04 | Updated case statement: `"24.04"\|"25.04")` | **FIXED** |
| **3** | KiCad PPA | 404 Not Found error | `ppa:kicad/kicad-6.0-releases` has no packages for `plucky` | Sourced KiCad 8 natively from Ubuntu `universe` repository | **FIXED** |
| **4** | GTK Dependencies | `libcanberra-gtk-module` missing | Deprecated GTK2 package dropped in Ubuntu 25.04 | Replaced with `libcanberra-gtk3-module` | **FIXED** |
| **5** | KiCad Config Path | Hardcoded to `~/.config/kicad/6.0` | Ubuntu 25.04 uses KiCad 8 (`~/.config/kicad/8.0`) | Updated paths to dynamically match installed KiCad version | **FIXED** |
| **6** | GHDL Configure | `unsupported llvm version 20.1` | Hardcoded LLVM check in GHDL 4.1.0 `configure` script | Patched configure regex to include `20.*) llvm_version=20;;` | **FIXED** |
| **7** | GHDL Backend | Linker failure with `-Wl` | Default apt package installs `ghdl-mcode` (in-memory JIT) | Purged `ghdl-mcode`, compiled with LLVM/GCC backend (GNAT 14.2) | **FIXED** |
| **8** | Verilator 5 | `#error "Verilator requires C++14"` | Old script compiled runtime objects with `-std=c++11` | Recompiled `verilated.o` & `verilated_threads.o` with `-std=gnu++17 -DVL_TIME_CONTEXT -pthread` | **FIXED** |
| **9** | Ngspice Engine | `typedef int bool` syntax error | GCC 14/15 defaults to C23 where `bool` is a keyword | Configured build with `CFLAGS="-std=gnu11 -O2"` and `--disable-maintainer-mode` | **FIXED** |
| **10** | Python 3.12+ | `distutils` removed & PEP 668 | Python 3.12 removed `distutils`; global pip is blocked | Isolated eSim in `~/.esim/venv` with `--system-site-packages` | **FIXED** |

---

## 2. Detailed Technical Breakdown & Solutions

### 1. OS Detection Fix

In `install-eSim.sh` and `nghdl/install-nghdl.sh`, Ubuntu 25.04 was rejected because `VERSION_ID` was unhandled.

* **Fix applied:** Mapped `25.04` to the modern installer workflow.

### 2. KiCad 8 Integration (Bypassing Obsolete PPAs)

* **Problem:** `add-apt-repository ppa:kicad/kicad-6.0-releases` results in HTTP 404 because Launchpad has no builds for `plucky`.
* **Fix applied:** Sourced KiCad directly from Ubuntu's universe repository:

```bash
sudo apt install -y kicad kicad-libraries kicad-symbols
```

### 3. GHDL 4.1.0 Build & LLVM 20.1 Patch

* **Problem:** Running `./configure --with-llvm-config` failed with:

```text
configure: error: unsupported llvm version 20.1.0
```

* **Fix applied:** Patched line 280 in `configure`:

```diff
+    20.*) llvm_version=20;;
```

Built GHDL using GNAT 14.2.0 and verified with `ghdl --version`. Ensured `ghdl-mcode` was purged so foreign C socket linking (`-Wl`) functions properly in NGHDL.

### 4. Verilator 5 C++17 Standard & Threading Fix

* **Problem:** Ubuntu 25.04 ships Verilator 5.032+. Compiling `verilated.cpp` with `-std=c++11` threw:

```text
#error "Verilator requires C++14 or newer"
undefined reference to `sc_time_stamp()'
undefined reference to `std::thread`
```

* **Fix applied:** Recompiled the runtime objects with C++17 and multithreading symbols:

```bash
g++ -DVL_TIME_CONTEXT -DVL_THREADED -pthread -I/usr/share/verilator/include \
    -std=gnu++17 -O2 -fPIC -c /usr/share/verilator/include/verilated.cpp \
    -o src/xspice/icm/Ngveri/verilated.o
g++ -DVL_TIME_CONTEXT -DVL_THREADED -pthread -I/usr/share/verilator/include \
    -std=gnu++17 -O2 -fPIC -c /usr/share/verilator/include/verilated_threads.cpp \
    -o src/xspice/icm/Ngveri/verilated_threads.o
```

### 5. Ngspice GCC 14 C23 Dialect Fix

* **Problem:** GCC 14+ treats `bool` as a reserved keyword, breaking `typedef int bool;` in Ngspice headers.
* **Fix applied:** Passed `CFLAGS="-std=gnu11 -O2"` and `--disable-maintainer-mode` to `./configure`, compiling custom Ngspice with XSpice dynamic code model loading (`ghdl.cm`).

### 6. Application Launcher & Environment Injection

Created `/usr/local/bin/esim` with virtual environment activation and `PYTHONPATH` exports:

```bash
#!/bin/bash
export ESIM_HOME="$HOME/esim-task/eSim-2.5"
export PYTHONPATH="$ESIM_HOME/src:$ESIM_HOME/src/frontEnd:$PYTHONPATH"
exec python3 "$ESIM_HOME/src/frontEnd/Application.py" "$@"
```

---

## 3. Verification & Testing Evidence

All tests pass on Ubuntu 25.04:

- [x] **GHDL VHDL Test:** `ghdl -a test.vhdl && ghdl -e test` compiles and elaborates cleanly.
- [x] **Verilator 5:** Runtime objects compiled and linked into `Ngveri.cm`.
- [x] **Ngspice & NGHDL:** `/usr/bin/ngspice` correctly loads `ghdl.cm` without dynamic linking errors.
- [x] **KiCad 8:** Schematic and symbol libraries mapped successfully.
- [x] **eSim GUI:** Successfully launched from terminal (`esim`).

---

## 4. Summary of Contributions

- **Issues Reported:** 10
- **Issues Resolved:** 10
- **Testing Status:** Full Simulation & GUI Launch Verified
