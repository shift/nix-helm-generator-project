## 🎯 Description

**What does this PR do?**
<!-- Provide a clear and concise description of what this pull request accomplishes -->

**Related Issue(s)**
<!-- Link to related issues: Fixes #123, Closes #456, Related to #789 -->

## 🔄 Type of Change

Please mark the relevant option(s):

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🧪 Test addition or improvement
- [ ] 🔧 CI/CD or build process change
- [ ] ♻️ Code refactoring (no functional changes)

## 🧪 Testing

**How has this been tested?**
<!-- Describe the tests you ran and how to reproduce them -->

- [ ] `nix flake check` passes
- [ ] `./cicd/test/validate-charts.sh` passes
- [ ] `./cicd/test/integration-test.sh` passes
- [ ] Manual testing performed
- [ ] Added new tests (if applicable)

**Test Configuration:**
- Nix version: 
- OS: 
- Related examples tested:

## 📝 Examples

**Before (if applicable):**
```nix
# Old behavior or configuration
```

**After:**
```nix
# New behavior or configuration
```

**Generated Output:**
```yaml
# Example of generated Kubernetes manifests (if applicable)
```

## ✅ Checklist

Please review and check all applicable items:

### Code Quality
- [ ] Code follows the project's style guidelines
- [ ] Self-review of my own code completed
- [ ] Code is commented, particularly in hard-to-understand areas
- [ ] No debugging code or console logs left in

### Testing
- [ ] Added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Integration tests pass
- [ ] Manual testing completed for affected areas

### Documentation
- [ ] Updated relevant documentation (README, API docs, etc.)
- [ ] Added/updated examples if applicable
- [ ] Updated CHANGELOG.md for significant changes
- [ ] Comments and docstrings updated

### Breaking Changes
- [ ] This change is backwards compatible
- [ ] If breaking changes exist, they are documented
- [ ] Migration guide provided (if needed)

## 🔍 Additional Notes

**Performance Impact:**
<!-- If applicable, describe any performance implications -->

**Security Considerations:**
<!-- If applicable, describe any security implications -->

**Deployment Notes:**
<!-- Any special considerations for deployment -->

**Future Work:**
<!-- Related work that could be done in future PRs -->

## 📸 Screenshots/Recordings

<!-- If applicable, add screenshots or recordings to help explain your changes -->

---

**Reviewer Guidelines:**
- Check that all tests pass
- Verify examples work as expected
- Review documentation updates
- Consider backwards compatibility
- Test with different Nix versions if possible