# eSim 2.5 on Ubuntu 25.04 (plucky): Installation Issues Report

**Environment:** Ubuntu 25.04 in VirtualBox, Python 3.13.3, KiCad 8.0.8 (pre-installed), eSim 2.5
**Method:** Ran `bash install-eSim.sh --install` and `nghdl/install-nghdl.sh --install`, and recorded the failures (logs and photos attached).

## Issues observed

### 1. KiCad 6 PPA returns 404 (observed)
- **Error:** `Err: https://ppa.launchpadcontent.net/kicad/kicad-6.0-releases/ubuntu plucky Release 404 Not Found` followed by `The repository ... does not have a Release file.`
- **Cause:** The KiCad 6.0 PPA has no packages for the `plucky` codename. The entry was present in my apt sources, and `apt update` fails on it.
- **Fix:** Remove the PPA with `add-apt-repository --remove ppa:kicad/kicad-6.0-releases`. Use KiCad from the Ubuntu repositories or the existing KiCad 8 install. The `installKicad` function checks for an existing KiCad with `kicad-cli version` and skips installation.
- **Status:** Workaround applied.

### 2. install-eSim.sh has no mapping for 25.04 (observed, fixed)
- **Symptom:** The installer only supports 18.04 to 24.04.
- **Fix:** Map 25.04 to `install-eSim-scripts/install-eSim-24.04.sh`. The log shows `Detected Ubuntu Version: 25.04` and `Running script: .../install-eSim-24.04.sh`.
- **Status:** Fixed.

### 3. nghdl/install-nghdl.sh rejects 25.04 (observed, fixed)
- **Error:** `Detected Ubuntu Version:` (empty) and `Unsupported Ubuntu version: 25.04 ()`
- **Cause:** The `case` block only handles 18.04 to 24.04, and `FULL_VERSION` is never set, so the message has empty parentheses.
- **Fix:** Line 46 changed from `"24.04")` to `"24.04"|"25.04")` (see `logs/diff_install-nghdl.txt`).
- **Result:** The error disappeared and the installer moved on to the next step (see issue 4).
- **Status:** Fixed.

### 4. libcanberra-gtk-module not available (observed)
- **Error:** `Package 'libcanberra-gtk-module' has no installation candidate` then `Aborting Installation...`
- **Cause:** The GTK2 package was dropped in 25.04, and GTK3 `libcanberra-gtk3-module` replaces it.
- **Fix:** `sed -i 's/libcanberra-gtk-module/libcanberra-gtk3-module/g'` in the install scripts.
- **Status:** [FIXED, applied / PROPOSED, not re-tested: keep the one that is true]

### 5. KiCad config path hardcoded to 6.0 (suspected, not tested)
- `copyKicadLibrary` in `install-eSim-24.04.sh` uses `~/.config/kicad/6.0`. Ubuntu 25.04 has KiCad 8, which uses `~/.config/kicad/8.0`.
- **Suggested fix:** replace `6.0` with `8.0`.
- **Status:** Not tested.

## Other observations (version checks on the VM)
- `ghdl --version` shows the mcode backend. NGHDL needs a backend that supports linking, so this may cause problems later.
- `verilator` and `ngspice` are not installed.
- I did not complete the NGHDL/Ngspice build because of time. This is not tested.

  ## Code changes (diff summary)

**nghdl/install-nghdl.sh, line 46**
```diff
- "24.04")
+ "24.04"|"25.04")
```

**nghdl/install-nghdl-scripts/install-nghdl-24.04.sh and install-eSim-scripts/install-eSim-24.04.sh**
```diff
- libcanberra-gtk-module
+ libcanberra-gtk3-module
```

## Summary
| Item | Count |
|---|---|
| Issues observed | 4 |
| Issues fixed | 2 to 3 (issues 2, 3 and possibly 4), plus a workaround for issue 1 |
| Suspected, not tested | 1 (issue 5) |
| Not completed | Full NGHDL build, library setup, GUI launch |
