---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: ['bug', 'triage']
assignees: ''
---

## 🐛 Bug Description

A clear and concise description of what the bug is.

## 🔄 Steps to Reproduce

1. Create a chart configuration with '...'
2. Run command '...'
3. Observe the error

## ✅ Expected Behavior

A clear and concise description of what you expected to happen.

## ❌ Actual Behavior

A clear and concise description of what actually happened.

## 📋 Environment

- **Nix Version**: [e.g., 2.15.0]
- **OS**: [e.g., Ubuntu 22.04, macOS 13.0]
- **Shell**: [e.g., bash 5.1]
- **flake-utils**: [e.g., latest/commit hash]

## 📝 Minimal Example

```nix
# Provide a minimal Nix expression that reproduces the issue
{
  name = "example-app";
  version = "1.0.0";
  app = {
    # ... configuration that causes the issue
  };
}
```

## 📊 Additional Context

Add any other context about the problem here:

- Error messages (full output)
- Screenshots if applicable
- Related issues or discussions
- Workarounds you've tried

## 🔍 Logs

<details>
<summary>Click to expand logs</summary>

```
# Paste relevant logs here
```

</details>

## ✅ Checklist

- [ ] I've searched for existing issues
- [ ] I've tested with the latest version
- [ ] I've provided a minimal reproduction case
- [ ] I've included environment information