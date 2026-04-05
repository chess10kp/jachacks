"""Mobile target implementation.

Android-first Tauri mobile target that reuses Jac web bundling.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Mobile build target - extends WebTarget with Tauri mobile wrapping."""
obj MobileTarget(WebTarget) {
    has name: str = "mobile",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "mobile",
        output_dir: Path = Path("src-tauri/gen/android/app/build/outputs");

    """Setup mobile target - scaffold Tauri project and android wrapper."""
    override def setup(project_dir: Path) -> None;

    """Build mobile app - build web bundle first, then run Tauri android build."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start mobile dev flow - launch Tauri Android dev."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start mobile app - build then run Android dev."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
