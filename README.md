# FaceStuff

This repository contains the Big Mac FaceTools project bootstrap for installing and running a local FaceFusion GUI on Big Mac through `ssh westcat`.

The actual project files are stored here as text-safe base64 bundle parts because Andrew could not download the ZIP artifact directly from ChatGPT.

## Hydrate the project files

From the MacBook project root:

```bash
cd "/Users/andrew/Library/Mobile Documents/com~apple~CloudDocs/Projects/FaceStuff"
bash hydrate_facetools_from_bundle_parts.sh --yes
```

That script reconstructs the original bundle from `bundle_parts/*.b64`, unpacks it into this project root, and marks shell scripts executable.

## After hydration

Run the normal audit/install flow:

```bash
cd "/Users/andrew/Library/Mobile Documents/com~apple~CloudDocs/Projects/FaceStuff"
find . -maxdepth 3 -type f | sort
bash -n install_bigmac_facetools.sh
find remote -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
python3 -m py_compile remote/gui/app.py
ssh westcat 'whoami && hostname && pwd && sw_vers'
./install_bigmac_facetools.sh --dry-run
```

Proceed to the real install only if the SSH route check returns first two lines exactly:

```text
bigmac
bigmac
```

## Forbidden shortcuts

Do not use or suggest:

- `ssh-copy-id westcat`
- creating a `westcat` user
- changing `Host westcat` back to `User andrew`
- disabling host key checking
- passing sudo passwords inline
- Screen Sharing
- recreating `com.apple.access_ssh`
- changing FileVault/SecureToken

Unless Andrew explicitly asks. Dexter growls at sloppy SSH. Correctly.
