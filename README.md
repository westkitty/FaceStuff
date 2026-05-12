# Big Mac FaceTools

A local-only FaceFusion installer and web GUI for Big Mac, controlled from a MacBook through `ssh westcat`.

The route is deliberately guarded. Every MacBook-side script verifies:

```bash
ssh westcat 'whoami && hostname && pwd && sw_vers'
```

The first two lines must be exactly:

```text
bigmac
bigmac
```

If `whoami` returns `andrew`, the scripts stop. That route is wrong for this project.

## Install

```bash
cd "/Users/andrew/Library/Mobile Documents/com~apple~CloudDocs/Projects/FaceStuff"
chmod +x *.sh
./install_bigmac_facetools.sh
```

Dry run:

```bash
./install_bigmac_facetools.sh --dry-run
```

Repair/update:

```bash
./update_bigmac_facetools.sh
```

Clean reinstall, keeping data:

```bash
./install_bigmac_facetools.sh --clean-reinstall
```

Uninstall, keeping data:

```bash
./install_bigmac_facetools.sh --uninstall
```

## Launch GUI

```bash
./launch_bigmac_facetools_gui.sh
```

Open:

```text
http://127.0.0.1:7865
```

## Stop GUI

```bash
./stop_bigmac_facetools_gui.sh
```

## Check diagnostics

```bash
./check_bigmac_facetools.sh
```

## Storage

Remote root:

```text
/Users/bigmac/AI/FaceTools
```

Managed data:

```text
/Users/bigmac/AI/FaceTools/data/uploads
/Users/bigmac/AI/FaceTools/data/outputs
/Users/bigmac/AI/FaceTools/data/jobs
/Users/bigmac/AI/FaceTools/logs
```

## Security

The GUI binds to `127.0.0.1` on Big Mac. The MacBook reaches it through an SSH tunnel. No cloud upload is performed by this wrapper. FaceFusion may download models from configured model providers during installation or first run.

Use only media you own, have rights to use, or have consent to process. Do not use this for deception, impersonation, harassment, or unlawful purposes.
