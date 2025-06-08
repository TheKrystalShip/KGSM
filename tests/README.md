# KGSM Testing Framework

This directory contains a testing framework for KGSM, providing integration and end-to-end tests.

## Directory Structure

```
testing/
├── README.md                 # This file
├── run-tests.sh              # Main entry point to run all tests
├── framework/                # Core testing framework components
│   ├── assert.sh             # Assertion library
│   ├── common.sh             # Common utilities for tests
│   ├── env-setup.sh          # Environment setup/teardown
│   ├── logger.sh             # Test logging facilities
│   ├── report.sh             # Test reporting utilities
│   └── runner.sh             # Test execution engine
├── integration/              # Integration tests (testing individual modules)
│   ├── test-blueprints.sh    # Tests for blueprints.sh
│   ├── test-directories.sh   # Tests for directories.sh
│   ├── test-files.sh         # Tests for files.sh
│   ├── test-instances.sh     # Tests for instances.sh
│   └── test-lifecycle.sh     # Tests for lifecycle.sh
└── e2e/                      # End-to-end tests
    ├── test-steam-server.sh  # Testing a Steam-based server (Necesse)
    ├── test-external-server.sh # Testing an external server (Factorio)
    └── test-container-server.sh # Testing a container server (VRising)
```

## Running Tests

To run all tests:

```bash
./testing/run-tests.sh
```

To run specific test categories:

```bash
./testing/run-tests.sh --integration  # Run only integration tests
./testing/run-tests.sh --e2e          # Run only end-to-end tests
```

To run a specific test:

```bash
./testing/run-tests.sh --test test-instances.sh
```

## Test Environment

Tests create a temporary environment using a copy of the entire KGSM project. Each test:

1. Sets up a fresh environment
2. Runs tests in isolation
3. Reports results
4. Cleans up the environment

## Extending the Framework

To add a new test:

1. Create a new test file in the appropriate directory
2. Source the framework's common.sh file
3. Define test cases using the assert functions
4. The test runner will automatically discover and execute your tests
