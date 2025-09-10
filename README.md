# ducksnest-homelab
This is Duck's hybrid homelab: NixOS on-prem, EC2 control plane, and full CI/CD automation.

## Migration to Full NixOS
Originally planned to use NixOS for on-premises infrastructure and Ubuntu for EC2 with Ansible and GitHub Actions for CI/CD pipeline. However, after discovering better practices for using NixOS on EC2, the project is transitioning to use NixOS for both on-premises and cloud infrastructure.

Previous Ubuntu-based work has been preserved in separate branches for backup purposes.
