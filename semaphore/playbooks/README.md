# Important Note About Group Variables

Due to how Ansible resolves paths, playbooks in the `playbooks/` subdirectory cannot automatically load variables from `group_vars/all/` in the parent directory.

## Solution

All playbooks in this directory must explicitly include vars_files:

```yaml
- name: Your Playbook
  hosts: jail_hosts
  vars_files:
    - ../group_vars/all/vars.yml
    - ../group_vars/all/secrets.yml
```

This ensures that variables are properly loaded regardless of playbook location.

## Root Cause

Ansible looks for `group_vars/` relative to the playbook file location, not the current working directory. Since these playbooks are in a subdirectory, they need explicit paths.
