"""Implementation of WatchTarget methods."""
import json;
import subprocess;
import shutil;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

glob DEFAULT_WATCH_APP_ID = "com.jac.app",
     DEFAULT_WATCH_APP_NAME = "Jac App",
     DEFAULT_WATCH_BUNDLE_ID = "com.jac.app.watchapp";

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
def _run_install_cmd(
    project_dir: Path, packages: list[str], dev: bool = False,
    legacy_peer_deps: bool = False
) -> None {
    pkg_json = project_dir / "package.json";
    if not pkg_json.exists() {
        pkg_data = {
            "name": "jac-watch-app",
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
        if legacy_peer_deps {
            cmd.append("--legacy-peer-deps");
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

"""Load watch config from jac.toml."""
def _load_watch_config(project_dir: Path) -> dict {
    try {
        import tomllib;
        toml_path = project_dir / "jac.toml";
        if toml_path.exists() {
            content = toml_path.read_text(encoding="utf-8");
            config = tomllib.loads(content);
            return config.get("plugins", {}).get("client", {}).get("watch", {});
        }
    } except Exception {
        ;
    }
    return {};
}

"""Write capacitor.config.json pointing webDir at the Vite output."""
def _write_capacitor_config(project_dir: Path, web_dist_dir: Path) -> None {
    watch_cfg = _load_watch_config(project_dir);
    app_id = watch_cfg.get("app_id", DEFAULT_WATCH_APP_ID);
    app_name = watch_cfg.get("app_name", DEFAULT_WATCH_APP_NAME);

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
            "iosScheme": "capacitor"
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

"""Ensure iOS platform is added."""
def _ensure_ios_platform(project_dir: Path, web_dist_dir: Path) -> None {
    ios_dir = project_dir / "ios";
    if ios_dir.exists() {
        console.print("  ✔ iOS platform already added", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/ios"]);
    _ensure_placeholder_index(web_dist_dir);
    _run_cap_cmd(project_dir, ["add", "ios"], "cap add ios");
    console.print("  ✔ iOS platform added", style="success");
}

"""Ensure @capacitor/watch plugin is installed."""
def _ensure_watch_plugin(project_dir: Path) -> None {
    node_modules = project_dir / "node_modules" / "@capacitor" / "watch";
    if node_modules.exists() {
        console.print("  ✔ @capacitor/watch already installed", style="muted");
        return;
    }
    # @capacitor/watch is experimental and may have peer dep conflicts
    _run_install_cmd(project_dir, ["@capacitor/watch"], legacy_peer_deps=True);
    console.print("  ✔ @capacitor/watch installed", style="success");
}

"""Generate the SwiftUI entry point file for the watch app."""
def _generate_watch_app_swift(project_dir: Path, watch_target_name: str) -> None {
    watch_app_dir = project_dir / "ios" / "App" / "watchapp";
    watch_app_dir.mkdir(parents=True, exist_ok=True);

    swift_file = watch_app_dir / "watchappApp.swift";
    swift_content = f'''import SwiftUI
import CapacitorWatch
import WatchConnectivity

@main
struct {watch_target_name}App: App {{
    @WKApplicationDelegateAdaptor(WatchDelegate.self) var delegate

    var body: some Scene {{
        WindowGroup {{
            CapWatchContentView()
        }}
    }}
}}

class WatchDelegate: NSObject, WKApplicationDelegate, WCSessionDelegate {{
    func applicationDidFinishLaunching() {{
        assert(WCSession.isSupported(), "WCSession is not supported")
        WCSession.default.delegate = self
        WCSession.default.activate()
    }}

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {{
        print("Watch WCSession activation: \\(activationState.rawValue)")
    }}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {{
        print("Watch received message: \\(message)")
    }}
}}
''';
    swift_file.write_text(swift_content, encoding="utf-8");
    console.print(f"  ✔ Generated {swift_file}", style="success");
}

"""Update AppDelegate.swift with WatchConnectivity and CapacitorWatch imports."""
def _update_app_delegate(project_dir: Path) -> None {
    app_delegate = project_dir / "ios" / "App" / "App" / "AppDelegate.swift";
    if not app_delegate.exists() {
        console.print("  ⚠ AppDelegate.swift not found, skipping update", style="warning");
        return;
    }

    content = app_delegate.read_text(encoding="utf-8");
    modified = False;

    if "import WatchConnectivity" not in content {
        content = content.replace(
            "import UIKit",
            "import UIKit\nimport WatchConnectivity",
            1
        );
        modified = True;
    }

    if "import CapacitorWatch" not in content {
        content = content.replace(
            "import Capacitor",
            "import Capacitor\nimport CapacitorWatch",
            1
        );
        modified = True;
    }

    wc_setup_code = "WCSession.default.delegate = self";
    if wc_setup_code not in content {
        launch_marker = "func application(_ application: UIApplication, didFinishLaunchingWithOptions";
        if launch_marker in content {
            wc_block = (
                "\n        // WatchConnectivity setup\n"
                "        if WCSession.isSupported() {\n"
                "            WCSession.default.delegate = self\n"
                "            WCSession.default.activate()\n"
                "        }\n"
            );
            content = content.replace(
                "return true",
                wc_block + "        return true",
                1
            );
            modified = True;
        }
    }

    if modified {
        app_delegate.write_text(content, encoding="utf-8");
        console.print("  ✔ Updated AppDelegate.swift with WatchConnectivity", style="success");
    } else {
        console.print("  ✔ AppDelegate.swift already configured", style="muted");
    }
}

"""Find the Xcode project/workspace path in ios/App/."""
def _find_xcode_project(project_dir: Path) -> Path {
    ios_app = project_dir / "ios" / "App";
    # Prefer .xcworkspace over .xcodeproj
    workspaces = list(ios_app.glob("*.xcworkspace"));
    if workspaces {
        return workspaces[0];
    }
    projects = list(ios_app.glob("*.xcodeproj"));
    if projects {
        return projects[0];
    }
    return ios_app;
}

"""Setup watch target - install Capacitor and scaffold iOS/watch project."""
impl WatchTarget.setup(project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    console.print("\n⌚ Setting up watch target (Capacitor Watch + iOS)", style="bold");

    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    web_dist_dir.mkdir(parents=True, exist_ok=True);

    _ensure_capacitor_deps(project_dir);
    _ensure_capacitor_config(project_dir, web_dist_dir);
    _ensure_ios_platform(project_dir, web_dist_dir);
    _ensure_watch_plugin(project_dir);

    console.print(
        "\n  📋 Manual Xcode steps required:\n"
        "     1. Open the Xcode project: npx cap open ios\n"
        "     2. Add a watchOS App target to the project\n"
        "     3. Add the CapacitorWatch Swift Package (from node_modules/@capacitor/watch)\n"
        "     4. Configure the watch app bundle identifier in Xcode\n",
        style="muted"
    );

    console.success("Watch target setup complete!");
}

"""Build watch app - build web bundle first, then sync and open Xcode."""
impl WatchTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    console.print("\n⌚ Building watch app (Capacitor Watch)", style="bold");

    self.setup(project_dir);

    console.print("  Step 1: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);

    console.print("  Step 2: Syncing with Capacitor...", style="muted");
    _run_cap_cmd(project_dir, ["sync", "ios"], "cap sync ios");
    console.print("  ✔ Capacitor sync complete", style="success");

    console.print(
        "\n  📋 To build the watch app, open Xcode and build from there:\n"
        "     npx cap open ios\n"
        "     (watchOS builds require Xcode provisioning profiles)\n",
        style="muted"
    );

    ios_output = project_dir / self.output_dir;
    console.success(f"Watch build ready: {ios_output}");
    return ios_output;
}

"""Start watch dev flow - build web bundle and launch Xcode."""
impl WatchTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    console.print("\n⌚ Starting watch dev flow (Capacitor Watch)", style="bold");

    self.setup(project_dir);

    web_bundle_path = super.build(entry_file, project_dir, None);

    _run_cap_cmd(project_dir, ["sync", "ios"], "cap sync ios");
    _run_cap_cmd(project_dir, ["open", "ios"], "cap open ios");
}

"""Start watch app - delegate to dev."""
impl WatchTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    self.dev(entry_file, project_dir, api_port);
}
