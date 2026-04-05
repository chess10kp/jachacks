"""Tests for mobile target registration and discovery."""

import tempfile;
import from pathlib { Path }

test "mobile target files exist" {
    plugin_dir = Path(__file__).parent.parent / "plugin";
    mobile_target_jac = plugin_dir / "src" / "targets" / "mobile_target.jac";
    mobile_target_impl = (
        plugin_dir / "src" / "targets" / "impl" / "mobile_target.impl.jac"
    );

    assert mobile_target_jac.exists() , (
        f"mobile_target.jac not found at {mobile_target_jac}"
    );
    assert mobile_target_impl.exists() , (
        f"mobile_target.impl.jac not found at {mobile_target_impl}"
    );

    mobile_content = mobile_target_jac.read_text();
    assert "obj MobileTarget" in mobile_content;
    assert "def setup" in mobile_content;
    assert "def build" in mobile_content;
    assert "def dev" in mobile_content;
    assert "def start" in mobile_content;
}

test "target type parser supports mobile" {
    plugin_dir = Path(__file__).parent.parent / "plugin";
    registry_path = plugin_dir / "src" / "targets" / "registry.jac";
    content = registry_path.read_text();

    assert 'MOBILE = "mobile"' in content;
    assert 'if name_lower == "mobile"' in content;
    assert "return TargetType.MOBILE" in content;
}

test "target factory supports mobile target" {
    plugin_dir = Path(__file__).parent.parent / "plugin";
    impl_path = plugin_dir / "src" / "targets" / "impl" / "registry.impl.jac";
    content = impl_path.read_text();

    assert "elif target_type == TargetType.MOBILE" in content;
    assert "MobileTarget" in content;
    assert "TargetType.MOBILE" in content;
}
