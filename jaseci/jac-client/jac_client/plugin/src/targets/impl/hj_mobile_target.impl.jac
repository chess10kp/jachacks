"""Implementation of HjMobileTarget methods."""
import from pathlib { Path }
import from typing { Optional }

"""Setup hijac target - delegates to Capacitor mobile target."""
impl HjMobileTarget.setup(project_dir: Path) -> None {
    super.setup(project_dir);
}

"""Build hijac app - delegates to Capacitor mobile target."""
impl HjMobileTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    return super.build(entry_file, project_dir, platform);
}

"""Start hijac dev flow - delegates to Capacitor mobile target."""
impl HjMobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    super.dev(entry_file, project_dir, api_port);
}

"""Start hijac app - delegates to Capacitor mobile target."""
impl HjMobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    super.start(entry_file, project_dir, api_port);
}
