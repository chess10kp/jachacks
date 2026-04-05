"""Hijac mobile target implementation.

Android-first Capacitor mobile target that reuses Jac web bundling.
Wraps the web bundle with Capacitor to produce a native Android APK.
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.capacitor_mobile_target { CapacitorMobileTarget }

"""Hijac build target - same pipeline as web, with Capacitor at the end."""
obj HjMobileTarget(CapacitorMobileTarget) {
    has name: str = "hj",
        default: bool = False,
        requires_setup: bool = True,
        config_section: str = "hj",
        output_dir: Path = Path("android/app/build/outputs");

    """Setup hijac target - install Capacitor deps and scaffold android project."""
    override def setup(project_dir: Path) -> None;

    """Build hijac app - build web bundle first, then sync and build Android APK."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Start hijac dev flow - build web bundle and launch on device."""
    override def dev(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;

    """Start hijac app - build then run on device."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
