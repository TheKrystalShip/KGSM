# KGSM Behavioral Uncertainty - Quick Reference Guide

## 🚨 What is Behavioral Uncertainty?

**Behavioral Uncertainty** occurs when the same KGSM command might succeed OR fail depending on implementation details, making it impossible to predict behavior or write reliable tests.

## 🔍 How to Identify Uncertain Behavior

### ❌ Signs of Uncertain Behavior
```bash
# Tests using uncertain if/else patterns
if "$INSTANCES_MODULE" --some-command; then
    log_test "Command succeeded (but we don't know why)"
else
    log_test "Command failed (but we don't know why)"
fi

# Comments indicating uncertainty
# "May succeed or fail depending on..."
# "Behavior varies based on..."
# "Sometimes works, sometimes doesn't..."
```

### ✅ Signs of Defined Behavior
```bash
# Tests using definitive assertions
assert_command_succeeds "$INSTANCES_MODULE --valid-command" "Should always succeed because X"
assert_command_fails "$INSTANCES_MODULE --invalid-command" "Should always fail because Y"
```

## 📋 Common Uncertainty Patterns

| Pattern | Uncertain Behavior | Defined Behavior |
|---------|-------------------|------------------|
| **Blueprint Validation** | May validate OR ignore | Always validate before proceeding |
| **Default Parameters** | May use defaults OR require explicit | Clear defaults documented and consistent |
| **Error Responses** | May exit OR continue with warnings | Consistent error handling patterns |
| **JSON Output** | May return JSON OR text OR fail | Always return valid JSON when requested |

## 🛠️ How to Fix Uncertain Behavior

### Step 1: Document Current Behavior
```bash
# Test what actually happens
echo "Testing current behavior..."
if "$INSTANCES_MODULE" --generate-id "nonexistent.bp"; then
    echo "Currently succeeds - generates ID regardless"
else
    echo "Currently fails - validates blueprint existence"
fi
```

### Step 2: Define Expected Behavior
```bash
# Decide what SHOULD happen
# Option A: Strict validation
assert_command_fails "$INSTANCES_MODULE --generate-id 'nonexistent.bp'" \
    "Should fail for non-existent blueprints"

# Option B: Permissive behavior
assert_command_succeeds "$INSTANCES_MODULE --generate-id 'nonexistent.bp'" \
    "Should generate ID regardless of blueprint existence"
```

### Step 3: Implement Consistent Behavior
```bash
# Update implementation to match defined behavior
function generate_id() {
    local blueprint="$1"

    # Implement defined behavior
    if [[ "$STRICT_VALIDATION" == "true" ]]; then
        validate_blueprint "$blueprint" || return 1
    fi

    generate_unique_id "$blueprint"
}
```

### Step 4: Add Behavioral Tests
```bash
# Add tests that enforce the defined behavior
function test_id_generation_behavior() {
    assert_command_succeeds "$INSTANCES_MODULE --generate-id 'factorio.bp'" \
        "ID generation must succeed for existing blueprints"

    assert_command_fails "$INSTANCES_MODULE --generate-id 'nonexistent.bp'" \
        "ID generation must fail for non-existent blueprints"
}
```

## 🎯 Decision Framework

When encountering uncertain behavior, ask:

### 1. **User Expectation**: What would users expect to happen?
- ✅ Intuitive behavior wins
- ❌ Technical convenience loses

### 2. **Consistency**: How do similar commands behave?
- ✅ Match existing patterns
- ❌ Create new inconsistencies

### 3. **Error Handling**: How should failures be communicated?
- ✅ Clear, actionable error messages
- ❌ Silent failures or cryptic errors

### 4. **Automation**: How will scripts use this command?
- ✅ Predictable, scriptable behavior
- ❌ Behavior that requires manual intervention

## 📝 Documentation Template

When documenting behavioral decisions:

```markdown
## Command: instances --generate-id

### Behavior Specification
- **Input**: Blueprint name (required)
- **Success Condition**: Blueprint file exists and is valid
- **Success Output**: Unique instance ID
- **Failure Condition**: Blueprint missing, invalid, or inaccessible
- **Failure Output**: Error message and exit code 1

### Examples
```bash
# Success case
$ instances --generate-id "factorio.bp"
factorio-instance-20250121-143052

# Failure case
$ instances --generate-id "nonexistent.bp"
Error: Blueprint 'nonexistent.bp' not found
```

### Test Coverage
- ✅ Valid blueprint generates ID
- ✅ Invalid blueprint returns error
- ✅ Empty blueprint name returns error
- ✅ Generated ID is unique
```

## 🚀 Quick Actions

### For Developers
1. **Before implementing**: Define expected behavior first
2. **During development**: Write behavioral tests alongside code
3. **Before merging**: Ensure no uncertain if/else patterns in tests
4. **After deployment**: Monitor for behavioral inconsistencies

### For Testers
1. **Identify uncertainty**: Look for if/else patterns in tests
2. **Document findings**: Record uncertain behaviors for resolution
3. **Suggest behavior**: Recommend expected behavior based on user needs
4. **Validate fixes**: Ensure implementations match defined behavior

### For Users
1. **Report inconsistencies**: When commands behave unpredictably
2. **Provide expectations**: What behavior you expect from commands
3. **Test edge cases**: Try unusual inputs and report results
4. **Validate documentation**: Confirm docs match actual behavior

## 📊 Success Metrics

Track these metrics to measure behavioral consistency:

- **Assertion Ratio**: % of tests using definitive assertions vs uncertain if/else
- **User Predictability**: User survey scores on command predictability
- **Bug Reports**: Reduction in behavior-related bug reports
- **Documentation Accuracy**: % of documented behavior matching actual behavior

## 🔗 Related Resources

- [Full Behavioral Uncertainty Discovery Document](behavioral_uncertainty_discovery.md)
- [Testing Framework Documentation](testing_framework.md)
- [KGSM Development Guidelines](../CONTRIBUTING.md)
- [Test-Driven Development Best Practices](https://example.com/tdd-best-practices)

---

**Remember**: Every uncertain behavior is an opportunity to improve KGSM's reliability and user experience. When in doubt, choose the behavior that makes the most sense to users!
