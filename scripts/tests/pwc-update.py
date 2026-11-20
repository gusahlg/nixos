"""Exercise updater transactions with real Git repositories and fake build/service tools."""
import json
import fcntl
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile

SCRIPT = Path(__file__).parent.parent / "pwc-update.sh"
REPOS = ("project_watt_cubed", "voxel-engine", "pwc-package-manager")
REAL_GIT = shutil.which("git")
REAL_CP = shutil.which("cp")
REAL_READLINK = shutil.which("readlink")

MOCK = r'''
import json, os, pathlib, shutil, subprocess, sys
r = pathlib.Path(os.environ["TEST_ROOT"])
name, args = sys.argv[1], sys.argv[2:]
state = r / "service.json"
s = json.loads(state.read_text())
home = r / "home"
server = home / ".local/state/watt-server"
mode = os.environ.get("TEST_FAIL", "")
if name == "git":
    if mode == "fetch" and "fetch" in args: sys.exit(64)
    args = [str(r / "upstreams" / (x.split("/")[-1])) if x.startswith("https://github.com/") and "fetch" in args else x for x in args]
    sys.exit(subprocess.call([os.environ["REAL_GIT"], *args]))
if name == "id":
    print("gusahlg" if "-un" in args else "1000"); sys.exit(0)
if name == "readlink":
    if args[-1].startswith("/proc/"):
        print(s["exe"]); sys.exit(0)
    sys.exit(subprocess.call([os.environ["REAL_READLINK"], *args]))
if name == "cp":
    args = [str(r / "old-server") if x.startswith("/proc/") else x for x in args]
    sys.exit(subprocess.call([os.environ["REAL_CP"], *args]))
if name == "nix-store":
    pathlib.Path(args[args.index("--add-root")+1]).symlink_to(r / "dev-env")
    sys.exit(0)
if name == "systemctl":
    if "show" in args:
        key = args[args.index("-p")+1]
        print(str(server / "launch.sh") if key == "ExecStart" else "4242")
    elif "is-active" in args:
        sys.exit(0 if s["active"] else 3)
    elif "stop" in args:
        s["active"] = False
        (home / "project_watt_cubed/world.save").write_text(s["world"])
    elif "start" in args:
        target = (server / "active-release").resolve()
        candidate = not target.name.startswith("baseline-")
        s["active"] = not (mode == "activation" and candidate)
        s["exe"] = str(target / "bin/watt_server")
        if candidate:
            s["world"] = "candidate-format"
            (home / "project_watt_cubed/world.save").write_text(s["world"])
        else:
            s["world"] = (home / "project_watt_cubed/world.save").read_text()
    state.write_text(json.dumps(s)); sys.exit(0)
if name == "ss":
    if s["active"]: print('UNCONN *:5555 users:(("watt_server",pid=4242,fd=1))')
    sys.exit(0)
if name == "journalctl":
    print("could not save world.save: fixture error" if mode == "save" else "fixture service log"); sys.exit(0)
if name == "nix":
    if "--profile" in args:
        pathlib.Path(args[args.index("--profile")+1]).symlink_to(r / "dev-env")
    print("noisy Nix shell hook", flush=True)
    command = args[args.index("--command")+1:]
    os.execvp(command[0], command)
if name == "cargo":
    if mode == "build": sys.exit(42)
    target = pathlib.Path(os.environ["CARGO_TARGET_DIR"]) / "release"
    target.mkdir(parents=True, exist_ok=True)
    repo = pathlib.Path.cwd().name
    if repo == "project_watt_cubed":
        body = '#!/usr/bin/env bash\ntrap \'printf "probe-save" > world.save; exit 0\' TERM\necho "watt-cubed server listening on [::]:12345"\nwhile :; do sleep 0.1; done\n'
        (target / "watt_server").write_text('#!/usr/bin/env bash\nexit 1\n' if mode == "probe" else body)
        (target / "watt_server").chmod(0o755)
    elif repo == "pwc-package-manager":
        (target / "pwc").write_text((r / "bin/pwc").read_text())
        (target / "pwc").chmod(0o755)
    sys.exit(0)
if name == "pwc":
    ph = pathlib.Path(os.environ["PWC_HOME"])
    lock = ph / "data/instances/update-check/pwc.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    lock.write_text("locked fixture mods")
    if "build" in args:
        build = ph / "cache/builds/fixture"
        (build / "bin").mkdir(parents=True, exist_ok=True)
        for binary in ("pwc-game", "pwc-golden"):
            (build / "bin" / binary).write_text("#!/bin/sh\nexit 0\n")
        print(build)
    sys.exit(0)
raise RuntimeError((name, args))
'''


def git(*args, cwd=None):
    return subprocess.check_output([REAL_GIT, *args], cwd=cwd, text=True, stderr=subprocess.DEVNULL).strip()


def fixture():
    root = Path(tempfile.mkdtemp(prefix="pwc-updater-test-"))
    home = root / "home"
    home.mkdir()
    (root / "upstreams").mkdir()
    heads = {}
    for repo in REPOS:
        source = root / ("upstream-src-" + repo)
        source.mkdir()
        git("init", "-b", "main", cwd=source)
        git("config", "user.email", "fixture@example.test", cwd=source)
        git("config", "user.name", "Fixture", cwd=source)
        (source / "source.txt").write_text("old")
        if repo == "project_watt_cubed":
            (source / "assets").mkdir()
            (source / "assets/content.txt").write_text("assets")
        if repo == "pwc-package-manager":
            (source / "mods/fixture").mkdir(parents=True)
            (source / "mods/fixture/mod.toml").write_text("mod fixture")
        git("add", ".", cwd=source)
        git("commit", "-m", "old", cwd=source)
        remote = root / "upstreams" / (repo + ".git")
        git("clone", "--bare", str(source), str(remote))
        checkout = home / repo
        git("clone", str(remote), str(checkout))
        git("config", "user.email", "fixture@example.test", cwd=checkout)
        git("config", "user.name", "Fixture", cwd=checkout)
        git("remote", "set-url", "origin", "https://github.com/gusahlg/" + repo + ".git", cwd=checkout)
        (source / "source.txt").write_text("new")
        git("commit", "-am", "new", cwd=source)
        git("push", str(remote), "main", cwd=source)
        heads[repo] = git("rev-parse", "HEAD", cwd=source)
    state = home / ".local/state/watt-server"
    state.mkdir(parents=True)
    (state / "launch.sh").write_text("original launcher")
    (root / "dev-env").mkdir()
    (state / "dev-shell").symlink_to(root / "dev-env")
    (root / "old-server").write_text("old executable")
    (root / "service.json").write_text(json.dumps({"active": True, "exe": str(home / "project_watt_cubed/target/release/watt_server"), "world": "original-world"}))
    (home / "project_watt_cubed/world.save").write_text("original-world")
    (home / "project_watt_cubed/world.save.bak").write_text("previous-world")
    mockdir = root / "bin"
    mockdir.mkdir()
    (mockdir / "mock.py").write_text(MOCK)
    for name in ("git", "id", "readlink", "cp", "nix-store", "systemctl", "ss", "journalctl", "nix", "cargo", "pwc"):
        wrapper = mockdir / name
        wrapper.write_text(f"#!/usr/bin/env bash\nexec {shlex.quote(sys.executable)} {shlex.quote(str(mockdir / 'mock.py'))} {name} \"$@\"\n")
        wrapper.chmod(0o755)
    text = SCRIPT.read_text().replace("@PWC_USER@", "gusahlg").replace("@PWC_HOME_DIR@", str(home))
    # Fixture sources live in /tmp; retain the real account HOME without changing it.
    text = text.replace('${HOME:-} == "$server_home"', '${HOME:-} == "' + os.environ["HOME"] + '"')
    script = root / "updater.sh"
    script.write_text(text)
    env = dict(os.environ, TEST_ROOT=str(root), REAL_GIT=REAL_GIT, REAL_CP=REAL_CP, REAL_READLINK=REAL_READLINK,
               PATH=str(mockdir) + ":" + os.environ["PATH"], PWC_UPDATE_HEALTH_TIMEOUT="2")
    return root, home, heads, script, env


def run_case(name, mutation=None, mode=None, check=False, success=False):
    root, home, heads, script, env = fixture()
    if mutation:
        mutation(root, home)
    if mode:
        env["TEST_FAIL"] = mode
    before = {repo: git("rev-parse", "HEAD", cwd=home / repo) for repo in REPOS}
    result = subprocess.run(["bash", str(script), *( ["--check"] if check else [])], env=env,
                            capture_output=True, text=True, timeout=60)
    (root / "result.log").write_text(result.stdout + result.stderr)
    assert (result.returncode == 0) == success, (name, result.returncode, root, result.stdout, result.stderr)
    state = home / ".local/state/watt-server"
    service = json.loads((root / "service.json").read_text())
    assert service["active"], (name, "service should be running", root)
    if name == "success":
        assert {repo: git("rev-parse", "HEAD", cwd=home / repo) for repo in REPOS} == heads
        assert (state / "active-release/bin/watt_server").is_file()
        assert (state / "active-release/bin/pwc-game").is_file()
        assert (state / "previous-release").is_symlink()
        assert (state / "active-release/rollback/world.save").read_text() == "original-world"
    else:
        assert (home / "project_watt_cubed/world.save").read_text() == "original-world", (name, "world was changed", root)
        assert (home / "project_watt_cubed/world.save.bak").read_text() == "previous-world"
        if mode in ("activation", "save"):
            assert (state / "active-release").resolve().name.startswith("baseline-")
            assert "Deployment failed; restoring" in result.stdout
            assert {repo: git("rev-parse", "HEAD", cwd=home / repo) for repo in REPOS} == heads
        else:
            assert {repo: git("rev-parse", "HEAD", cwd=home / repo) for repo in REPOS} == before
    for repo in REPOS:
        assert "update-" not in git("worktree", "list", cwd=home / repo), (name, "worktree leaked")
    print("PASS", name, flush=True)
    shutil.rmtree(root)


run_case("check", check=True, success=True)
run_case("tracked edits", mutation=lambda r, h: (h / REPOS[0] / "source.txt").write_text("user edits"))
run_case("wrong branch", mutation=lambda r, h: git("switch", "-c", "feature", cwd=h / REPOS[0]))

def divergent(r, h):
    (h / REPOS[1] / "local.txt").write_text("user commit")
    git("add", ".", cwd=h / REPOS[1])
    git("commit", "-m", "local", cwd=h / REPOS[1])

run_case("divergence", mutation=divergent)

def collision(r, h):
    upstream = r / ("upstream-src-" + REPOS[0])
    (upstream / "notes.txt").write_text("upstream file")
    git("add", ".", cwd=upstream)
    git("commit", "-m", "new file", cwd=upstream)
    git("push", str(r / "upstreams" / (REPOS[0] + ".git")), "main", cwd=upstream)
    (h / REPOS[0] / "notes.txt").write_text("user's untracked notes")

run_case("untracked collision", mutation=collision)
run_case("build failure", mode="build")
run_case("fetch failure", mode="fetch")
run_case("candidate startup failure", mode="probe")
run_case("shutdown save failure", mode="save")
run_case("activation failure restores world and old server", mode="activation")
run_case("success", success=True)

lock_handles = []

def hold_lock(r, h):
    handle = (h / ".local/state/watt-server/update.lock").open("w")
    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    lock_handles.append(handle)

run_case("concurrent update lock", mutation=hold_lock)
for handle in lock_handles:
    handle.close()
