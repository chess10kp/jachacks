"""Capacitor Watch target implementation.

Capacitor Watch target that reuses Jac web bundling.
Wraps the web bundle with Capacitor to produce a watchOS app via iOS.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Watch build target - extends WebTarget with Capacitor Watch wrapping."""
obj WatchTarget(WebTarget) {
    has name: str = "watch",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "watch",
        output_dir: Path = Path("ios/App/build");

    """Setup watch target - install Capacitor deps and scaffold iOS/watch project."""
    override def setup(project_dir: Path) -> None;

    """Build watch app - build web bundle first, then sync and open Xcode."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start watch dev flow - build web bundle and launch Xcode."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start watch app - delegate to dev."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
