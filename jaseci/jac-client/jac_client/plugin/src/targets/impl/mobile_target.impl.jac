"""Implementation of MobileTarget methods."""
import json;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

"""Normalize platform for Android-first mobile target."""
def _normalize_mobile_platform(platform: Optional[str] = None) -> str {
    if (platform is None) or (platform.strip() == "") {
        return "android";
    }
    value = platform.lower().strip();
    if value == "android" {
        return value;
    }
    raise ValueError(
        f"Unsupported mobile platform '{platform}'. Supported: android"
    );
}

"""Resolve tauri CLI command prefix.

Prefers cargo-tauri and falls back to bun-based script execution.
"""
def _resolve_tauri_cmd_prefix(project_dir: Path) -> list[str] {
    try {
        result = subprocess.run(
            ["cargo", "tauri", "--version"], capture_output=True, timeout=5
        );
        if result.returncode == 0 {
            return ["cargo", "tauri"];
        }
    } except Exception {
        ;
    }

    # Fallback for projects using a JS script wrapper.
    try {
        subprocess.run(["bun", "--version"], capture_output=True, check=True, timeout=5);
        return ["bun", "run", "tauri"];
    } except Exception {
        ;
    }

    raise RuntimeError(
        "Tauri CLI not found. Install with: cargo install tauri-cli "
        "or bun add -g @tauri-apps/cli"
    );
}

"""Run a tauri mobile command from project root."""
def _run_tauri_mobile_cmd(project_dir: Path, args: list[str], label: str) -> None {
    cmd = _resolve_tauri_cmd_prefix(project_dir) + args;
    console.print(f"  Running {label}: {' '.join(cmd)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Update tauri.conf.json frontendDist for packaged mobile builds."""
def _update_tauri_config_for_mobile_build(
    project_dir: Path, web_bundle_path: Path
) -> None {
    tauri_dir = project_dir / "src-tauri";
    config_path = tauri_dir / "tauri.conf.json";
    if not config_path.exists() {
        raise RuntimeError("tauri.conf.json not found. Run 'jac setup mobile' first.");
    }

    with open(config_path, "r") as f {
        config = json.load(f);
    }
    dist_dir = web_bundle_path.parent;
    try {
        dist_relative = dist_dir.relative_to(project_dir);
        dist_relative_str = "../" + str(dist_relative.as_posix());
    } except ValueError {
        dist_relative_str = str(dist_dir.as_posix());
    }

    if "build" not in config {
        config["build"] = {};
    }
    config["build"]["frontendDist"] = dist_relative_str;
    if "devUrl" in config["build"] {
        del config["build"]["devUrl"];
    }
    if "devPath" in config["build"] {
        del config["build"]["devPath"];
    }
    if "distDir" in config["build"] {
        del config["build"]["distDir"];
    }
    if "withGlobalTauri" in config["build"] {
        del config["build"]["withGlobalTauri"];
    }

    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    console.print("  ✔ Updated tauri.conf.json for mobile build", style="success");
}

"""Find newest Android artifact (APK/AAB), fallback to outputs directory."""
def _find_android_artifact(project_dir: Path) -> Path {
    outputs_root = project_dir / "src-tauri" / "gen" / "android" / "app" / "build" / "outputs";
    if not outputs_root.exists() {
        return outputs_root;
    }

    artifacts = [];
    for ext in [".apk", ".aab"] {
        artifacts.extend([f for f in outputs_root.rglob(f"*{ext}") if f.is_file()]);
    }
    if artifacts {
        artifacts.sort(key=lambda p: p.stat().st_mtime, reverse=True);
        return artifacts[0];
    }
    return outputs_root;
}

"""Ensure baseline Tauri scaffolding exists by delegating to desktop setup."""
def _ensure_tauri_scaffold(project_dir: Path) -> None {
    tauri_dir = project_dir / "src-tauri";
    if tauri_dir.exists() {
        return;
    }
    import from jac_client.plugin.src.targets.desktop_target { DesktopTarget }
    desktop = DesktopTarget();
    desktop.setup(project_dir);
}

"""Setup mobile target - scaffold Tauri project and android wrapper."""
impl MobileTarget.setup(project_dir: Path) -> None {
    console.print("\n📱 Setting up mobile target (Tauri Android)", style="bold");
    _ensure_tauri_scaffold(project_dir);

    # Initialize Android wrapper if not already initialized.
    android_gen_dir = project_dir / "src-tauri" / "gen" / "android";
    if android_gen_dir.exists() {
        console.print("  ✔ Android wrapper already initialized", style="muted");
        return;
    }

    try {
        _run_tauri_mobile_cmd(project_dir, ["android", "init", "--ci"], "tauri android init");
    } except Exception {
        # Some CLI versions may not support --ci.
        _run_tauri_mobile_cmd(project_dir, ["android", "init"], "tauri android init");
    }
    console.success("Mobile target setup complete!");
}

"""Build mobile app - build web bundle first, then run Tauri android build."""
impl MobileTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    selected_platform = _normalize_mobile_platform(platform);
    if selected_platform != "android" {
        raise ValueError(
            f"Unsupported mobile platform '{selected_platform}'. Supported: android"
        );
    }

    console.print("\n📱 Building mobile app (Tauri Android)", style="bold");
    _ensure_tauri_scaffold(project_dir);
    self.setup(project_dir);

    console.print("  Step 1: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    console.print("  Step 2: Updating mobile Tauri config...", style="muted");
    _update_tauri_config_for_mobile_build(project_dir, web_bundle_path);

    console.print("  Step 3: Running Android build...", style="muted");
    _run_tauri_mobile_cmd(project_dir, ["android", "build"], "tauri android build");

    artifact = _find_android_artifact(project_dir);
    console.success(f"Mobile build complete: {artifact}");
    return artifact;
}

"""Start mobile dev flow - launch Tauri Android dev."""
impl MobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    console.print("\n📱 Starting mobile dev flow (Tauri Android)", style="bold");
    _ensure_tauri_scaffold(project_dir);
    self.setup(project_dir);

    # Build bundle first so mobile can run against packaged frontendDist.
    web_bundle_path = super.build(entry_file, project_dir, None);
    _update_tauri_config_for_mobile_build(project_dir, web_bundle_path);
    _run_tauri_mobile_cmd(project_dir, ["android", "dev"], "tauri android dev");
}

"""Start mobile app - build then run Android dev."""
impl MobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    self.dev(entry_file, project_dir, api_port);
}
