"""Implementation of CapacitorMobileTarget methods."""
import json;
import subprocess;
import shutil;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

glob DEFAULT_APP_ID = "com.jac.app",
     DEFAULT_APP_NAME = "Jac App";

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

"""Resolve npx command prefix."""
def _resolve_npx -> str {
    try {
        subprocess.run(
            ["npx", "--version"], capture_output=True, check=True, timeout=5
        );
        return "npx";
    } except Exception {
        ;
    }
    try {
        subprocess.run(
            ["bunx", "--version"], capture_output=True, check=True, timeout=5
        );
        return "bunx";
    } except Exception {
        ;
    }
    raise RuntimeError(
        "npx or bunx not found. Install Node.js (https://nodejs.org) "
        "or Bun (https://bun.sh)."
    );
}

"""Run a Capacitor CLI command from project root."""
def _run_cap_cmd(project_dir: Path, args: list[str], label: str) -> None {
    npx = _resolve_npx();
    cmd = [npx, "cap"] + args;
    console.print(f"  Running {label}: {' '.join(cmd)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Run an npm/bun install command."""
def _run_install_cmd(project_dir: Path, packages: list[str], dev: bool = False) -> None {
    pkg_json = project_dir / "package.json";
    if not pkg_json.exists() {
        # Create minimal package.json if missing
        pkg_data = {
            "name": "jac-mobile-app",
            "version": "1.0.0",
            "private": True,
            "type": "module"
        };
        pkg_json.write_text(json.dumps(pkg_data, indent=2), encoding="utf-8");
        console.print("  ✔ Created package.json", style="success");
    }
    try {
        subprocess.run(
            ["npm", "--version"], capture_output=True, check=True, timeout=5
        );
        cmd = ["npm", "install"];
        if dev {
            cmd.append("--save-dev");
        }
        cmd.extend(packages);
    } except Exception {
        cmd = ["bun", "add"];
        if dev {
            cmd.append("--dev");
        }
        cmd.extend(packages);
    }
    console.print(f"  Installing: {' '.join(packages)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Load mobile config from jac.toml."""
def _load_mobile_config(project_dir: Path) -> dict {
    try {
        import tomllib;
        toml_path = project_dir / "jac.toml";
        if toml_path.exists() {
            content = toml_path.read_text(encoding="utf-8");
            config = tomllib.loads(content);
            return config.get("plugins", {}).get("client", {}).get("mobile", {});
        }
    } except Exception {
        ;
    }
    return {};
}

"""Write capacitor.config.json pointing webDir at the Vite output."""
def _write_capacitor_config(project_dir: Path, web_dist_dir: Path) -> None {
    mobile_cfg = _load_mobile_config(project_dir);
    app_id = mobile_cfg.get("app_id", DEFAULT_APP_ID);
    app_name = mobile_cfg.get("app_name", DEFAULT_APP_NAME);

    # Resolve webDir relative to project root
    try {
        web_dir_rel = str(web_dist_dir.relative_to(project_dir));
    } except ValueError {
        web_dir_rel = str(web_dist_dir);
    }

    config = {
        "appId": app_id,
        "appName": app_name,
        "webDir": web_dir_rel,
        "server": {
            "androidScheme": "https"
        }
    };
    config_path = project_dir / "capacitor.config.json";
    config_path.write_text(json.dumps(config, indent=2), encoding="utf-8");
    console.print("  ✔ Wrote capacitor.config.json", style="success");
}

"""Ensure Capacitor dependencies are installed."""
def _ensure_capacitor_deps(project_dir: Path) -> None {
    node_modules = project_dir / "node_modules" / "@capacitor" / "cli";
    if node_modules.exists() {
        console.print("  ✔ Capacitor dependencies already installed", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/core"]);
    _run_install_cmd(project_dir, ["@capacitor/cli"], dev=True);
}

"""Ensure Capacitor config exists."""
def _ensure_capacitor_config(project_dir: Path, web_dist_dir: Path) -> None {
    config_path = project_dir / "capacitor.config.json";
    if config_path.exists() {
        # Update webDir in case it changed
        try {
            existing = json.loads(config_path.read_text(encoding="utf-8"));
            web_dir_rel = str(web_dist_dir.relative_to(project_dir));
            if existing.get("webDir") != web_dir_rel {
                existing["webDir"] = web_dir_rel;
                config_path.write_text(
                    json.dumps(existing, indent=2), encoding="utf-8"
                );
                console.print("  ✔ Updated capacitor.config.json webDir", style="muted");
            } else {
                console.print("  ✔ capacitor.config.json already exists", style="muted");
            }
        } except Exception {
            console.print("  ✔ capacitor.config.json already exists", style="muted");
        }
        return;
    }
    _write_capacitor_config(project_dir, web_dist_dir);
}

"""Ensure web dist directory has at least a placeholder index.html.

Capacitor's 'add' and 'sync' commands require an index.html in webDir.
"""
def _ensure_placeholder_index(web_dist_dir: Path) -> None {
    index_html = web_dist_dir / "index.html";
    if index_html.exists() {
        return;
    }
    web_dist_dir.mkdir(parents=True, exist_ok=True);
    index_html.write_text(
        '<!DOCTYPE html><html><head></head><body></body></html>',
        encoding="utf-8"
    );
}

"""Ensure Android platform is added."""
def _ensure_android_platform(project_dir: Path, web_dist_dir: Path) -> None {
    android_dir = project_dir / "android";
    if android_dir.exists() {
        console.print("  ✔ Android platform already added", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/android"]);
    # Capacitor needs an index.html in webDir during 'add'
    _ensure_placeholder_index(web_dist_dir);
    _run_cap_cmd(project_dir, ["add", "android"], "cap add android");
    console.print("  ✔ Android platform added", style="success");
}

"""Find newest Android APK artifact."""
def _find_android_apk(project_dir: Path) -> Path {
    outputs_root = project_dir / "android" / "app" / "build" / "outputs";
    if not outputs_root.exists() {
        return outputs_root;
    }
    apks = [f for f in outputs_root.rglob("*.apk") if f.is_file()];
    if apks {
        apks.sort(key=lambda p: p.stat().st_mtime, reverse=True);
        return apks[0];
    }
    return outputs_root;
}

"""Resolve gradlew path and ensure it is executable."""
def _resolve_gradlew(project_dir: Path) -> str {
    gradlew = project_dir / "android" / "gradlew";
    if gradlew.exists() {
        import os;
        import stat;
        st = os.stat(gradlew);
        os.chmod(gradlew, st.st_mode | stat.S_IEXEC);
        return str(gradlew);
    }
    return "gradle";
}

"""Setup mobile target - install Capacitor and scaffold Android project."""
impl CapacitorMobileTarget.setup(project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    console.print("\n📱 Setting up mobile target (Capacitor Android)", style="bold");

    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    # Ensure dist dir exists so Capacitor doesn't complain
    web_dist_dir.mkdir(parents=True, exist_ok=True);

    _ensure_capacitor_deps(project_dir);
    _ensure_capacitor_config(project_dir, web_dist_dir);
    _ensure_android_platform(project_dir, web_dist_dir);

    console.success("Mobile target setup complete!");
}

"""Build mobile app - build web bundle first, then sync and build Android APK."""
impl CapacitorMobileTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    selected_platform = _normalize_mobile_platform(platform);
    if selected_platform != "android" {
        raise ValueError(
            f"Unsupported mobile platform '{selected_platform}'. Supported: android"
        );
    }

    console.print("\n📱 Building mobile app (Capacitor Android)", style="bold");

    # Ensure Capacitor scaffold exists
    self.setup(project_dir);

    console.print("  Step 1: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    # Ensure webDir is up to date in config
    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);

    console.print("  Step 2: Syncing with Capacitor...", style="muted");
    _run_cap_cmd(project_dir, ["sync", "android"], "cap sync android");
    console.print("  ✔ Capacitor sync complete", style="success");

    console.print("  Step 3: Building Android APK...", style="muted");
    gradlew = _resolve_gradlew(project_dir);
    android_dir = project_dir / "android";
    subprocess.run(
        [gradlew, "assembleDebug"],
        cwd=android_dir,
        check=True,
        capture_output=False
    );

    artifact = _find_android_apk(project_dir);
    console.success(f"Mobile build complete: {artifact}");
    return artifact;
}

"""Start mobile dev flow - build web bundle and launch on connected device."""
impl CapacitorMobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    console.print("\n📱 Starting mobile dev flow (Capacitor Android)", style="bold");

    # Ensure scaffold
    self.setup(project_dir);

    # Build web bundle
    web_bundle_path = super.build(entry_file, project_dir, None);

    # Sync and run on device
    _run_cap_cmd(project_dir, ["sync", "android"], "cap sync android");
    _run_cap_cmd(project_dir, ["run", "android"], "cap run android");
}

"""Start mobile app - build then run on device."""
impl CapacitorMobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    self.dev(entry_file, project_dir, api_port);
}
