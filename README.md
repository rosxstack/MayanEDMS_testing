# Mayan EDMS – Test Suite

This folder contains the automated tests for our Mayan EDMS deployment: functional (UI/API) tests written in [Robot Framework](https://robotframework.org/) and a performance test script.

## Table of Contents

- [Folder Structure](#folder-structure)
- [Test Coverage](#test-coverage)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Running the Tests](#running-the-tests)
- [Test Results](#test-results)
- [Writing New Tests](#writing-new-tests)
- [Troubleshooting](#troubleshooting)

## Folder Structure

```
tests/
├── data/                 # Test data (e.g. sample.txt used for document uploads)
├── functional/           # Robot Framework functional tests
│   ├── F04_DocumentOrganisation.robot
│   ├── F09_AuditLogging.robot
│   ├── N02_AccessControl.robot
│   ├── debug_api.robot
│   ├── debug_negative.robot
│   └── debug_negative2.robot
├── performance/
│   └── Perf_test.py      # Performance test script
├── resources/
│   └── common.resource   # Shared keywords, variables and settings
├── __init__.py
└── readme.md
```

## Test Coverage

| ID / File | Area | Description |
| --------- | ---- | ----------- |
| `F04_DocumentOrganisation.robot` | Functional | Document organisation (e.g. cabinets, tags, metadata) |
| `F09_AuditLogging.robot` | Functional | Audit logging of user and system actions |
| `N02_AccessControl.robot` | Non-functional | Access control and permissions |
| `debug_api.robot` | Debug | API checks used while developing and diagnosing |
| `debug_negative.robot`, `debug_negative2.robot` | Debug | Negative test cases (invalid input, unauthorised access) |
| `Perf_test.py` | Performance | Load and response-time testing |

> Update the descriptions above to match the exact scope of each suite.

## Prerequisites

- Python 3.9+
- [Docker](https://www.docker.com/) and Docker Compose (to run Mayan EDMS)
- A browser and matching driver for UI tests (Chrome, Firefox or Edge)
- Project requirements (see the `requirements/` folder at the repo root)

## Setup

1. **Start Mayan EDMS** from the repository root:

   ```bash
   docker compose up -d
   ```

   Make sure the values in `docker/.env` are configured.

2. **Create a virtual environment and install dependencies:**

   ```bash
   python -m venv .venv
   .venv\Scripts\activate        # Windows
   # source .venv/bin/activate   # macOS / Linux

   pip install robotframework robotframework-seleniumlibrary robotframework-requests
   ```

   Install any extra packages your tests need (for example the performance test's dependencies).

3. **Configure test settings.** Shared variables such as the base URL, username and password live in `resources/common.resource`. Check they point to your running instance.

## Running the Tests

Run all functional tests:

```bash
robot --outputdir results tests/functional
```

Run a single suite:

```bash
robot --outputdir results tests/functional/F04_DocumentOrganisation.robot
```

Run in a specific browser (if `common.resource` exposes a `${BROWSER}` variable):

```bash
robot --variable BROWSER:firefox --outputdir results_firefox tests/functional
robot --variable BROWSER:edge    --outputdir results_edge    tests/functional
```

Run the performance test:

```bash
python tests/performance/Perf_test.py
```

## Test Results

Robot Framework writes `report.html`, `log.html` and `output.xml` to the chosen output directory. Results folders at the repo root are used for different runs:

| Folder | Purpose |
| ------ | ------- |
| `results/` | Default functional run |
| `results_debug/` | Debug runs |
| `results_edge/`, `results_firefox/` | Cross-browser runs |
| `results_perf/`, `results_perf_run2/` | Performance runs |

Open `report.html` for a summary and `log.html` for step-by-step detail.

## Writing New Tests

- Put new Robot suites in `functional/` and follow the existing naming pattern (`F##_Name.robot` for functional requirements, `N##_Name.robot` for non-functional).
- Reuse keywords from `resources/common.resource` rather than duplicating them.
- Put upload files and fixtures in `data/`.
- Keep tests independent: each should set up and clean up its own data.

## Troubleshooting

- **Cannot connect to Mayan:** confirm the containers are running (`docker compose ps`) and the base URL in `common.resource` is correct.
- **Login fails:** check the credentials in `docker/.env` and `common.resource`.
- **Browser driver errors:** make sure your browser and its driver versions match.