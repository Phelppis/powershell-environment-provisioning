# Environment Provisioning Toolkit — English Summary

A **public, generic PowerShell portfolio sample** demonstrating Windows laboratory automation, SQL Server backup restoration, controlled MSI/EXE installation, and non-destructive IIS provisioning.

- **Core:** reusable PowerShell module (`src/ProvisioningToolkit.psm1`).
- **GUI:** read-only Windows Forms preview (`gui/Start-Gui.ps1`).
- **CLI:** preview by default; changes require `-Apply -ConfirmEnvironment LAB`.
- **Configuration:** fictional resources in `examples/config.sample.json`.
- **Quality:** Pester tests and GitHub Actions checks.

Run `.\Invoke-Provisioning.ps1` for a safe preview. Before using the apply mode, read `docs/SAFETY.md` and configure only an isolated environment you control. Never use this sample for production without additional design, security review, integration tests, and operational safeguards.

This independent sample does **not** contain employer-specific source code, passwords, infrastructure endpoints, or proprietary installer binaries. See the [full Brazilian Portuguese README](README.md) for examples and details.
