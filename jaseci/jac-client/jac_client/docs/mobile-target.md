# Mobile Target (Tauri Android)

Jac client now includes an Android-first mobile target powered by Tauri.

## Commands

- Setup mobile scaffolding:
  - `jac setup mobile`
- Build Android mobile artifact:
  - `jac build main.jac --client mobile --platform android`
- Run Android dev flow:
  - `jac start main.jac --client mobile --dev`

## Notes

- The first setup/build may download Android and Rust dependencies.
- Current v1 scope is Android. iOS is not included yet.
- Mobile target reuses the standard Jac web bundle output and wraps it with Tauri Android tooling.
