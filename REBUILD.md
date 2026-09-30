# REBUILD.md — Rebuilding Rx Price Watch from an empty Codespace

This is the **order of operations** for rebuilding the whole project yourself, file by file, in GitHub Codespaces. Follow it top to bottom. Every step says exactly what to create, what to type, what to run, and what you should see.

It was tested by rebuilding the project in exactly this order and running every check. The expected outputs below are real.

---

## How this guide works

You'll have two copies of the project side by side in your Codespace:

| Folder | What it is | Do you edit it? |
|---|---|---|
| `/workspaces/rx-price-watch` | **Your replica**: the public repo you're building | ✅ Yes, you type everything here |
| `/workspaces/reference` | **The reference build**: your private `rx-price-watch-reference` repo | ❌ Read-only. You only look at it. |

Every step uses the same symbols:

- 📄 **Type**: create a file in your replica and type it by reading the reference. Don't copy and paste. Typing is how it becomes intuitive, and you can explain every line on camera.
- ▶️ **Run**: a command to run in the terminal.
- ✅ **Expect**: what success looks like. **Don't move on until you see it.**
- 🧠 **Notice**: the ideas to pay attention to while typing (also good talking points for your video).

### Helper commands (installed automatically in Part A)

| Command | What it does |
|---|---|
| `refat <tag>` | Moves the reference to a module's snapshot, e.g. `refat module-02-dbt-local`. **Run it at the start of every module**, so the reference shows exactly what that module should contain. |
| `mk <path>` | Creates an empty file in your replica (and any missing folders) and opens it |
| `ref <path>` | Opens the same file from the reference in an editor tab |
| `same <path>` | Checks your typed file against the reference in the terminal. Prints `identical: …` or shows the differences. |
| `check <path>` | Opens a side-by-side diff of your file and the reference in VS Code |
| `loadenv` | Loads your `.env` settings into the current terminal (needed for dbt + Snowflake in Module 4) |

**All paths are relative to the repo root**, e.g. `mk src/rx_ingest/config.py`. Tip: after `mk` and `ref`, right-click the reference tab and choose **Split Right** so you can read on the right and type on the left.

> `same` is strict: a different comment or blank line counts as a difference. Differences in *comments* are fine (write your own!). Differences in *code* are what you're hunting for.

### The end-of-module ritual (you'll do this 8 times)

```bash
cd /workspaces/rx-price-watch
git add -A
git status          # read it! .env, include/data/, include/keys/, dbt/target/ must NOT be listed
git commit -m "Module N: <description>"
git tag module-0N-<name>
git push && git push --tags
```

---

## Table of contents

- [Part A — Before you open a Codespace (on github.com)](#part-a--before-you-open-a-codespace-on-githubcom)
- [Part B — First session in the Codespace](#part-b--first-session-in-the-codespace)
- [Module 0 — Project skeleton](#module-0--project-skeleton)
- [Module 1 — Ingestion (Python → Parquet → S3)](#module-1--ingestion-python--parquet--s3)
- [Module 2 — dbt on DuckDB (staging → star schema)](#module-2--dbt-on-duckdb-staging--star-schema)
- [Module 3 — History & quality](#module-3--history--quality)
- [Module 4 — Snowflake](#module-4--snowflake)
- [Module 5 — Airflow](#module-5--airflow)
- [Module 6 — CI/CD & monitoring](#module-6--cicd--monitoring)
- [Module 7 — Dashboard & ship](#module-7--dashboard--ship)
- [Appendix 1 — Master file checklist](#appendix-1--master-file-checklist)
- [Appendix 2 — When something doesn't match](#appendix-2--when-something-doesnt-match)
- [Appendix 3 — Codespace hours, costs and cleanup](#appendix-3--codespace-hours-costs-and-cleanup)

---

## Part A — Before you open a Codespace (on github.com)

You'll add two small files to your replica repo *before* creating the Codespace. They make every Codespace you open come with Python 3.12, Docker, Terraform, the AWS CLI, the GitHub CLI, the Astro CLI, the reference repo and the helper commands. Order matters: GitHub only asks permission to read your private reference repo when a Codespace is **created**.

**Prerequisites:** `rx-price-watch-reference` is pushed to GitHub (private, with its 8 tags), and your `rx-price-watch` repo exists (public, with a starter README).

### A1. Create `.devcontainer/devcontainer.json`

1. Go to `https://github.com/miltonsuggs/rx-price-watch`.
2. Click **Add file → Create new file**.
3. In the name box type `.devcontainer/devcontainer.json` (typing the `/` creates the folder).
4. Paste this. It's configuration, not project code, so pasting is fine here:

```json
{
  "name": "rx-price-watch",
  "image": "mcr.microsoft.com/devcontainers/universal:2",
  "forwardPorts": [8501, 8080],
  "portsAttributes": {
    "8501": { "label": "Streamlit dashboard" },
    "8080": { "label": "Airflow UI / dbt docs" }
  },
  "postCreateCommand": "bash .devcontainer/post-create.sh",
  "customizations": {
    "codespaces": {
      "repositories": {
        "miltonsuggs/rx-price-watch-reference": {
          "permissions": { "contents": "read" }
        }
      }
    },
    "vscode": {
      "extensions": [
        "ms-python.python",
        "charliermarsh.ruff",
        "innoverio.vscode-dbt-power-user",
        "hashicorp.terraform",
        "ms-azuretools.vscode-docker",
        "mechatroner.rainbow-csv"
      ]
    }
  }
}
```

5. Click **Commit changes… → Commit directly to the main branch → Commit changes**.

🧠 **Notice:** `image` is Microsoft's **universal** Codespaces image. It already includes Python, Docker, Git and the GitHub CLI, and it's cached on Codespaces machines, so it starts fast and can't fail to build. The other tools (Terraform, AWS CLI, Astro CLI) are installed by the script below, where a failure only prints a warning instead of breaking the whole Codespace. `customizations.codespaces.repositories` grants read access to your private reference repo. `postCreateCommand` runs the script once.

### A2. Create `.devcontainer/post-create.sh`

Same steps: **Add file → Create new file**, name `.devcontainer/post-create.sh`, paste, commit:

```bash
#!/usr/bin/env bash
# Runs once when the Codespace is created (and again after a rebuild).
# Every install is allowed to fail without breaking the Codespace: failures
# print a "!!" line and you can re-run this script later with:
#   bash .devcontainer/post-create.sh
set -uo pipefail

if ! command -v unzip >/dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -y -qq unzip
fi

echo "==> Installing Terraform"
if ! command -v terraform >/dev/null 2>&1; then
  TF_VERSION=$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform 2>/dev/null \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['current_version'])" 2>/dev/null)
  TF_VERSION=${TF_VERSION:-1.9.8}
  curl -fsSL -o /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" \
    && sudo unzip -o -q /tmp/terraform.zip terraform -d /usr/local/bin \
    || echo "!! Terraform install failed - re-run: bash .devcontainer/post-create.sh"
fi

echo "==> Installing the AWS CLI"
if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    && unzip -o -q /tmp/awscliv2.zip -d /tmp \
    && sudo /tmp/aws/install --update \
    || echo "!! AWS CLI install failed - re-run: bash .devcontainer/post-create.sh"
fi

echo "==> Installing the Astro CLI (needed in Module 5)"
if ! command -v astro >/dev/null 2>&1; then
  curl -sSL install.astronomer.io | sudo bash -s \
    || echo "!! Astro CLI install failed - re-run: bash .devcontainer/post-create.sh"
fi

echo "==> Cloning the reference build into /workspaces/reference"
if [ ! -d /workspaces/reference/.git ]; then
  git clone https://github.com/miltonsuggs/rx-price-watch-reference.git /workspaces/reference \
    || echo "!! Could not clone the reference repo - see REBUILD.md step B2"
fi

echo "==> Adding rx-price-watch helper commands to ~/.bashrc"
if ! grep -q "rx-price-watch helpers" ~/.bashrc; then
  cat >> ~/.bashrc <<'BASHRC'

# --- rx-price-watch helpers (added by .devcontainer/post-create.sh) ---
export RX_PROJECT_ROOT=/workspaces/rx-price-watch
export REF=/workspaces/reference
[ -f "$RX_PROJECT_ROOT/.venv/bin/activate" ] && source "$RX_PROJECT_ROOT/.venv/bin/activate"
refat()   { git -C "$REF" checkout -q "$1" && echo "reference is now at $1"; }
ref()     { code "$REF/$1"; }
mk()      { mkdir -p "$(dirname "$RX_PROJECT_ROOT/$1")" && touch "$RX_PROJECT_ROOT/$1" && code "$RX_PROJECT_ROOT/$1"; }
check()   { code --diff "$REF/$1" "$RX_PROJECT_ROOT/$1"; }
same()    { if cmp -s "$REF/$1" "$RX_PROJECT_ROOT/$1"; then echo "identical: $1"; else diff -u "$REF/$1" "$RX_PROJECT_ROOT/$1" | head -40; fi; }
loadenv() { set -a; source "$RX_PROJECT_ROOT/.env"; set +a; echo "loaded .env into this terminal"; }
BASHRC
fi
echo "==> Done. Open a NEW terminal (Ctrl+Shift+\`) so the helpers load."
```

### A3. Add this guide to the repo

**Add file → Upload files**, drag in `REBUILD.md`, and before committing change the path so it lands in `docs/REBUILD.md` (or upload it to the root and move it later with `git mv REBUILD.md docs/`). Commit.

### A4. Create the Codespace

1. On the repo page: **Code → Codespaces → ⋯ (three dots) → New with options…**
2. Branch `main`, **Machine type: 2-core** (you'll switch to 4-core for Module 5), then **Create codespace**.
3. GitHub shows **"Authorize and continue"** for access to `rx-price-watch-reference`. Click it. (If you skip it, the reference won't clone; see B2.)
4. Wait for the build (several minutes the first time). When the terminal says `==> Done`, press **Ctrl+Shift+`** to open a **new** terminal.

---

## Part B — First session in the Codespace

### B1. Check the tools

▶️ Run:

```bash
python3 --version && git --version && docker --version && terraform -version | head -1 && aws --version && gh --version | head -1 && astro version
```

✅ **Expect:** Python 3.11 or newer, and a version line for each tool.

If any tool is missing, the setup script printed a `!!` line for it. Re-run it (it skips anything already installed):

```bash
bash .devcontainer/post-create.sh
```

**If the Codespace opens in "recovery mode"** (a pop-up says so, and almost nothing is installed), the container build failed. Press Ctrl+Shift+P → **Codespaces: View Creation Log**, search for the first `ERROR`, fix `devcontainer.json`, commit, then Ctrl+Shift+P → **Codespaces: Full Rebuild Container**, or delete the Codespace and create a new one.

---

### B2. Check the reference repo

▶️ `ls /workspaces/reference && git -C /workspaces/reference tag`

✅ **Expect:** the project files and 8 tags, `module-00-setup` … `module-07-ship`.

**If `/workspaces/reference` is missing**, use either fallback:

- **Option 1 — GitHub CLI login:**
  ```bash
  GITHUB_TOKEN= gh auth login        # GitHub.com → HTTPS → login with a web browser
  GITHUB_TOKEN= gh repo clone miltonsuggs/rx-price-watch-reference /workspaces/reference
  ```
- **Option 2 — upload the zip:**
  1. Drag `rx-price-watch.zip` from your Mac into the VS Code **Explorer** panel.
  2. Run (this unzips to a temporary folder first, so it can't collide with your replica folder of the same name):
     ```bash
     unzip -q /workspaces/rx-price-watch/rx-price-watch.zip -d /tmp/ref-unzip
     mv /tmp/ref-unzip/rx-price-watch /workspaces/reference
     rm /workspaces/rx-price-watch/rx-price-watch.zip      # never commit the zip
     ```
  3. Check with `git -C /workspaces/reference tag`.

### B3. See the finish line first

Run the finished reference once so you know what you're building:

```bash
cd /workspaces/reference
git checkout -q main
make setup           # creates the reference's own .venv (3–5 minutes)
make demo            # sample data → DuckDB → dbt
make dashboard       # starts Streamlit on port 8501
```

✅ **Expect:** `make demo` ends with `Done. PASS=67 WARN=1 ERROR=0 SKIP=0 NO-OP=1 … TOTAL=69`. A pop-up says a port was forwarded. Click **Open in Browser**, or use the **Ports** tab → 8501 → 🌐. You should see the dashboard with five tabs.

Press **Ctrl+C** in the terminal to stop the dashboard.

> The one **WARN** is intentional: the sample data contains a fake one-week price spike, and the anomaly test is supposed to catch it. You'll build that test in Module 3.

### B4. Get your bearings

```bash
cd /workspaces/rx-price-watch
ls -a                # README.md, .devcontainer/, docs/REBUILD.md
type refat mk ref same check loadenv   # the helpers exist
```

Open this guide in the Codespace in preview mode: right-click `docs/REBUILD.md` → **Open Preview**.

---

## Module 0 — Project skeleton

> **Goal:** the files every project needs before any real code: ignore rules, settings template, packaging, Makefile, editor settings.
> **Files:** 8 · **Reference guide:** `docs/00-setup.md`

▶️ **Start the module:**

```bash
cd /workspaces/rx-price-watch
refat module-00-setup
```

### 0.1 `.gitignore`

📄 **Type:** `mk .gitignore` then `ref .gitignore`

🧠 **Notice:** it ignores secrets (`.env`, `include/keys/`, `*.p8`, `terraform.tfvars`, `*.tfstate`), data (`include/data/`), and generated folders (`dbt/target/`, `dbt/dbt_packages/`, `.venv/`). A secret committed to Git is compromised forever, even if you delete it later.

▶️ **Run:**

```bash
git check-ignore .env include/data/raw/x.parquet include/keys/rsa_key.p8 infra/terraform/terraform.tfvars
```

✅ **Expect:** all four paths printed back. Each one is ignored.

### 0.2 `LICENSE` and `.env.example`

📄 **Type:** `mk LICENSE` (MIT; change the name/year if you like), then `mk .env.example`, with `ref .env.example` open alongside.

🧠 **Notice:** `.env.example` documents every setting, grouped by module, with **blank secrets**. It's committed. Your real `.env` is a copy that is never committed.

▶️ **Run:**

```bash
cp .env.example .env
git status --short
```

✅ **Expect:** `.env.example` and `LICENSE` listed as new files; `.env` **not** listed.

### 0.3 `pyproject.toml`

📄 **Type:** `mk pyproject.toml` / `ref pyproject.toml`

🧠 **Notice:**
- `[project] dependencies` is only what ingestion needs.
- `[project.optional-dependencies]` groups extras per module (`s3`, `dbt`, `snowflake`, `dashboard`, `dev`).
- `[project.scripts]` creates the commands `rx-ingest`, `rx-load` and `rx-sample-data`.
- `[tool.setuptools.packages.find] where = ["src"]` says the code lives in `src/`.

▶️ **Run:**

```bash
python3 -c "import tomllib; print(tomllib.load(open('pyproject.toml','rb'))['project']['name'])"
```

✅ **Expect:** `rx-price-watch`

### 0.4 `Makefile` (with one deliberate change)

📄 **Type:** `mk Makefile` / `ref Makefile`

⚠️ **Deliberate difference from the reference.** In the `lint:` and `fmt:` targets, type `.` instead of `src tests dags dashboard`:

```makefile
lint: ## Lint Python (ruff) and SQL (sqlfluff)
	$(BIN)/ruff check .
	$(BIN)/ruff format --check .
	cd dbt && $(BIN)/sqlfluff lint models tests/singular

fmt: ## Auto-format Python
	$(BIN)/ruff check --fix .
	$(BIN)/ruff format .
```

**Why:** the reference names folders that don't exist yet in early modules, and ruff errors on missing folders. `.` means "everything", and `pyproject.toml` already excludes what shouldn't be linted. `same Makefile` will show exactly these 4 lines as different, and that's expected.

🧠 **Notice:**
- `-include .env` + `export` passes your settings to every command.
- `RX_PROJECT_ROOT := $(CURDIR)` pins paths to the project root.
- `##` comments become the help text.
- **Recipe lines must start with a TAB, not spaces.** VS Code uses tabs in Makefiles automatically. If you ever see `missing separator`, a line has spaces.

▶️ **Run:** `make help`

✅ **Expect:** a list of targets grouped by module (Module 0 — Setup, Module 1 — Ingestion, …).

### 0.5 `.vscode/extensions.json` and `.vscode/settings.json`

📄 **Type:** `mk .vscode/extensions.json`, `mk .vscode/settings.json` (and `ref` each).

▶️ **Run:**

```bash
python3 -m json.tool .vscode/extensions.json >/dev/null && python3 -m json.tool .vscode/settings.json >/dev/null && echo json-ok
```

✅ **Expect:** `json-ok`

### 0.6 `include/README.md`

📄 **Type:** `mk include/README.md` / `ref include/README.md`

🧠 **Notice:** `include/` is shared with Airflow's containers later. Its `data/` and `keys/` subfolders are git-ignored; the README keeps the folder in Git.

### 0.7 Your README and the module guide

1. Replace `README.md` with your own short work-in-progress version, for example:

   ```markdown
   # 💊 Rx Price Watch

   An end-to-end drug-pricing data platform (Python · AWS S3 · Terraform · Snowflake · dbt · Airflow · Streamlit),
   built module by module. Follow along on YouTube: <playlist link>

   ## Progress
   - [x] Module 0 — Project skeleton
   - [ ] Module 1 — Ingestion
   - [ ] Module 2 — dbt on DuckDB
   - [ ] Module 3 — History & quality
   - [ ] Module 4 — Snowflake
   - [ ] Module 5 — Airflow
   - [ ] Module 6 — CI/CD & monitoring
   - [ ] Module 7 — Dashboard & ship
   ```

2. Copy the module guide. Guides are documentation, so copying is fine:

   ```bash
   cp $REF/docs/00-setup.md docs/
   ```

### ✅ Module 0 done: commit and tag

```bash
git add -A && git status
git commit -m "Module 0: project skeleton, tooling and setup guide"
git tag module-00-setup
git push && git push --tags
```

---

## Module 1 — Ingestion (Python → Parquet → S3)

> **Goal:** a Python package that downloads NADAC, Medicare Part D and the FDA NDC Directory, and lands them as Parquet files locally or in S3. Plus the S3 bucket, built with Terraform.
> **Files:** 24 · **Reference guide:** `docs/01-ingestion.md` (read its "Concepts" and "The three sources in depth" sections before you start)

▶️ `refat module-01-ingestion`

### Part 1 — The Python package (local only, no AWS needed)

#### 1.1 Package marker, then install everything

📄 **Type:** `mk src/rx_ingest/__init__.py` / `ref src/rx_ingest/__init__.py`

⚠️ **Order matters:** install *after* this file exists. If you install before `src/rx_ingest/` exists, the package won't be importable later.

▶️ **Run:**

```bash
make setup                 # creates .venv, installs all extras (3–5 minutes)
source ~/.bashrc           # auto-activates .venv in this and future terminals
python -c "import rx_ingest; print(rx_ingest.__version__)"
```

✅ **Expect:** `✅ Setup complete…` then `1.0.0`. Your prompt now starts with `(.venv)`.

#### 1.2 `config.py`: all settings in one object

📄 **Type:** `mk src/rx_ingest/config.py` / `ref src/rx_ingest/config.py`

🧠 **Notice:**
- `Settings.from_env()` reads environment variables.
- `load_dotenv(override=False)` means real environment variables beat `.env`.
- Relative paths resolve from the project root.

▶️ **Run:**

```bash
python -c "from rx_ingest.config import Settings; s=Settings.from_env(); print(s.project_root, s.storage_backend, s.warehouse); print(s.duckdb_path)"
```

✅ **Expect:**

```text
/workspaces/rx-price-watch local duckdb
/workspaces/rx-price-watch/include/data/warehouse/rx_price_watch.duckdb
```

#### 1.3 `http_client.py`: retries and timeouts

📄 **Type:** `mk src/rx_ingest/http_client.py` / `ref src/rx_ingest/http_client.py`

🧠 **Notice:** `TimeoutSession` exists because `requests` has **no default timeout**. `Retry(...)` retries on 429/5xx with exponential backoff and honors `Retry-After`.

▶️ **Run:**

```bash
python -c "from rx_ingest.http_client import build_session; s=build_session('rx-price-watch-test'); print(type(s).__name__, s.headers['User-Agent'])"
```

✅ **Expect:** `TimeoutSession rx-price-watch-test`

#### 1.4 Storage, the Parquet contract, and manifests (+ their tests)

📄 **Type, in this order:**

1. `mk src/rx_ingest/storage.py`: `LocalStorage` and `S3Storage` behind one interface.
2. `mk src/rx_ingest/raw.py`: records → all-text Parquet plus the `_batch_id`, `_ingested_at` and `_source` lineage columns.
3. `mk src/rx_ingest/manifest.py`: a small JSON audit record per landed partition.
4. `mk tests/test_raw_and_storage.py`

🧠 **Notice:**
- The atomic write in `LocalStorage` (temp file + rename).
- Why everything lands as **text** (see the docstring in `raw.py`).
- The test proving leading zeros survive (`00002322730`).

▶️ **Run:** `pytest tests/test_raw_and_storage.py`

✅ **Expect:** `4 passed`

#### 1.5 NDC normalization (+ tests)

📄 **Type:** `mk src/rx_ingest/ndc.py`, then `mk tests/test_ndc.py`. Consider typing the test first: it's a spec of what the function must do.

🧠 **Notice:** the whole trick is `p.zfill(w) for p, w in zip(parts, (5, 4, 2))`. A 10-digit value *without* hyphens is ambiguous, so it returns `None` rather than guessing.

▶️ **Run:**

```bash
pytest tests/test_ndc.py
python -c "from rx_ingest.ndc import normalize_ndc as n; print(n('0002-3227-30'), n('50090-348-00'), n('68180-231-9'), n('1234567890'))"
```

✅ **Expect:** `15 passed`, then `00002322730 50090034800 68180023109 None`

#### 1.6 The NADAC connector (+ tests)

📄 **Type:**

1. `mk src/rx_ingest/sources/__init__.py`
2. `mk src/rx_ingest/sources/nadac.py` (the biggest file so far: take your time)
3. `mk tests/test_nadac.py`

🧠 **Notice:**
- `discover_dataset_id` (search, then a known-id fallback).
- The paging loop in `fetch_publication` and the completeness check (`IncompleteExtractError`).
- Half-open windows in `days()`.
- The deterministic file path in `partition_key()`, which makes re-runs idempotent.
- In the test file, how `responses` fakes the API so tests never hit the internet.

▶️ **Run:** `pytest tests/test_nadac.py`

✅ **Expect:** `7 passed`

#### 1.7 Part D and openFDA connectors (+ tests)

📄 **Type:**

1. `mk src/rx_ingest/sources/partd.py`: note the wide→long `unpivot()` and the `"Overall"` row trap.
2. `mk src/rx_ingest/sources/openfda_ndc.py`: note the bulk download and `flatten()` into products and packages.
3. `mk tests/test_partd_openfda.py`

▶️ **Run:** `pytest tests/test_partd_openfda.py`

✅ **Expect:** `3 passed`

#### 1.8 The CLI, then a real extract

📄 **Type:** `mk src/rx_ingest/cli.py` / `ref src/rx_ingest/cli.py`

▶️ **Run:**

```bash
rx-ingest --help
rx-ingest nadac --weeks-back 2          # REAL data from data.medicaid.gov
ls include/data/raw/nadac/
cat include/data/raw/_manifests/nadac/*.json
```

✅ **Expect:**
- The help text.
- Log lines like `Landed NADAC 2026-09-23: 2xxxx rows -> …`.
- One `as_of_date=…` folder per weekly publication.
- A manifest showing `rows` and a `sha256`.

(If it finds no publications, widen the window: `--weeks-back 4`.)

▶️ **Run the same command again**, then `find include/data/raw/nadac -name "*.parquet" | wc -l`

✅ **Expect:** the same number of files as before. The re-run overwrote them rather than adding more. **That's idempotency.**

▶️ **Optional:** try the reference sources too.

```bash
rx-ingest partd && rx-ingest openfda-ndc      # openfda downloads a large zip (1–3 minutes)
```

#### 1.9 Sample data (for fast, offline development)

📄 **Type:** `mk src/rx_ingest/sample_data.py` / `ref src/rx_ingest/sample_data.py`

🧠 **Notice:** it builds payloads shaped like the real APIs and pushes them through the **same** landing functions. It deliberately includes messy cases: all three NDC layouts, a drug missing from the FDA directory, and a price spike.

⚠️ **Never mix real and sample data in the same folder.** Wipe the real data first:

▶️ **Run:**

```bash
make clean                     # deletes include/data (all landed files)
rx-sample-data
find include/data/raw -name "*.parquet" | wc -l
python -c "import duckdb; print(duckdb.sql(\"select as_of_date, count(*) as n from 'include/data/raw/nadac/**/*.parquet' group by 1 order by 1 desc limit 3\"))"
```

✅ **Expect:** `19` Parquet files (16 NADAC weeks + 1 Part D + 2 openFDA), and the three latest weeks shown with 27 rows each (`2026-09-23`, `2026-09-16`, `2026-09-09`).

#### 1.10 Full test suite and lint

▶️ **Run:**

```bash
make test
ruff check . && ruff format --check .
```

✅ **Expect:** `29 passed`, `All checks passed!`, `… files already formatted`.

(If ruff reports formatting differences, run `make fmt`, then `same <file>` to see what changed.)

### Part 2 — Terraform + S3

#### 1.11 Terraform files

📄 **Type, in this order**, all in `infra/terraform/` (use `mk infra/terraform/<file>`):

1. `versions.tf`: provider pins; `default_tags` on everything.
2. `variables.tf`: inputs. Note `budget_email` has no default, so it's required.
3. `s3.tf`: bucket + public-access block + versioning + encryption + lifecycle.
4. `iam_ingest.tf`: a least-privilege user for your ingestion code.
5. `budget.tf`: a $5/month cost alert.
6. `outputs.tf`: values you'll copy into `.env` later.
7. `terraform.tfvars.example`

▶️ **Run:**

```bash
terraform -chdir=infra/terraform init
terraform -chdir=infra/terraform validate
terraform -chdir=infra/terraform fmt -check
```

✅ **Expect:** `Terraform has been successfully initialized!`, `Success! The configuration is valid.`, and no output from `fmt -check`.

#### 1.12 AWS account and admin credentials (one time)

1. If you don't have an AWS account, create one at aws.amazon.com and enable **MFA on the root user** (IAM → Dashboard).
2. Create an admin user for yourself, so you never use root keys:
   1. **IAM → Users → Create user**, name `milton-admin`.
   2. **Attach policies directly** → select `AdministratorAccess` → Create.
3. Open the new user → **Security credentials → Create access key → Command Line Interface (CLI)** → confirm → **copy both values**. The secret is shown only once.
4. In the Codespace, run:

   ```bash
   aws configure                    # paste key id + secret, region: us-east-1, output: json
   aws sts get-caller-identity
   ```

   ✅ **Expect:** JSON showing `"Arn": "arn:aws:iam::<account>:user/milton-admin"`.

#### 1.13 Create the bucket

▶️ **Run:**

```bash
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
code infra/terraform/terraform.tfvars          # set budget_email = "your email"; leave aws_profile = "default"
terraform -chdir=infra/terraform plan
```

✅ **Expect:** `Plan: 10 to add, 0 to change, 0 to destroy.` Read the plan: bucket, public-access block, versioning, encryption, lifecycle, random suffix, IAM user, policy, attachment, budget.

▶️ **Run:**

```bash
terraform -chdir=infra/terraform apply          # type: yes
terraform -chdir=infra/terraform output
```

✅ **Expect:** `Apply complete! Resources: 10 added`, then outputs including `bucket_name = "rx-price-watch-raw-xxxxxx"`.

#### 1.14 Credentials for the least-privilege ingest user

▶️ **Run:**

```bash
aws iam create-access-key --user-name rx-price-watch-ingest     # copy AccessKeyId + SecretAccessKey
aws configure --profile rx-price-watch                          # paste them; region us-east-1; output json
aws sts get-caller-identity --profile rx-price-watch
```

✅ **Expect:** an ARN ending in `:user/rx-price-watch-ingest`.

#### 1.15 Land real data in S3

1. Edit `.env` (`code .env`) and set:

   ```bash
   RX_STORAGE=s3
   RX_S3_BUCKET=<bucket_name from the terraform output>
   AWS_PROFILE=rx-price-watch
   ```

2. ▶️ Run:

   ```bash
   make ingest
   aws s3 ls s3://$(terraform -chdir=infra/terraform output -raw bucket_name)/raw/ --recursive --profile rx-price-watch
   ```

   ✅ **Expect:** Parquet files and manifests listed under `raw/nadac/…` in S3.

3. **Switch back to local mode** for Modules 2–3 by editing `.env`:

   ```bash
   RX_STORAGE=local
   ```

   Then rebuild the local sample data:

   ```bash
   make clean && rx-sample-data
   ```

### ✅ Module 1 done

```bash
cp $REF/docs/01-ingestion.md docs/
# tick "Module 1" in your README
git add -A && git status        # confirm: no .env, no include/data, no terraform.tfvars, no *.tfstate
git commit -m "Module 1: ingestion package, sample data, tests and S3 via Terraform"
git tag module-01-ingestion
git push && git push --tags
```

(`infra/terraform/.terraform.lock.hcl` **should** be committed: it pins provider versions, like a lock file.)

---

## Module 2 — dbt on DuckDB (staging → star schema)

> **Goal:** load the landed files into a local DuckDB warehouse and build the dbt project: staging → intermediate → marts, with tests.
> **Files:** 36 · **Reference guide:** `docs/02-dbt-local.md` (read "Concepts" first)

▶️ `refat module-02-dbt-local`

### 2.1 The DuckDB loader

📄 **Type, in this order:**

1. `mk src/rx_ingest/loaders/__init__.py`: `RAW_TABLES`, the single source of truth for raw table names and columns.
2. `mk src/rx_ingest/loaders/duckdb_loader.py`
3. `mk src/rx_ingest/loaders/cli.py`

▶️ **Run:**

```bash
make clean && rx-sample-data && rx-load duckdb
```

✅ **Expect** (at the end):

```json
{
  "nadac": 432,
  "partd_spending": 265,
  "openfda_ndc_products": 26,
  "openfda_ndc_packages": 26
}
```

### 2.2 Pipeline smoke test

📄 **Type:** `mk tests/test_pipeline_smoke.py`

▶️ **Run:** `pytest`

✅ **Expect:** `31 passed`

### 2.3 dbt project skeleton

▶️ **Create the folders:**

```bash
mkdir -p dbt/{models/{staging,intermediate,marts},macros,seeds,snapshots,tests/{generic,singular}}
```

📄 **Type:**

1. `mk dbt/dbt_project.yml`: layers → schemas and materializations; `vars`.
2. `mk dbt/profiles.yml`: a `dev` (DuckDB) target and a `snowflake` target, all values from environment variables.
3. `mk dbt/packages.yml`

▶️ **Run:**

```bash
cd dbt
dbt deps
dbt debug
```

✅ **Expect:** `Installed from version …` for dbt_utils, then `Connection test: [OK connection ok]` and `All checks passed!`

(From here on, most dbt commands run from inside `dbt/`. `mk`, `ref` and `same` still take paths from the repo root, e.g. `mk dbt/macros/ndc.sql`.)

### 2.4 Macros

📄 **Type, in this order:**

1. `mk dbt/macros/generate_schema_name.sql`
2. `mk dbt/macros/cross_db.sql`: note `adapter.dispatch` and the DuckDB `'g'` flag.
3. `mk dbt/macros/casting.sql`
4. `mk dbt/macros/ndc.sql`: the SQL twin of `ndc.py`.

▶️ **Run** (from `dbt/`):

```bash
dbt show --inline "select {{ normalize_ndc(\"'68180-231-9'\") }} as ndc11"
dbt show --inline "select {{ normalize_ndc(\"'1234567890'\") }} as ndc11"
```

✅ **Expect:** a one-row table showing `68180023109`, then a one-row table with an **empty** value (NULL: ambiguous input is rejected).

### 2.5 Custom generic tests and seeds

📄 **Type:**

1. `mk dbt/tests/generic/is_valid_ndc11.sql`
2. `mk dbt/tests/generic/positive_value.sql`
3. `mk dbt/seeds/rate_setting_classifications.csv`
4. `mk dbt/seeds/pricing_units.csv`
5. `mk dbt/seeds/_seeds.yml`

▶️ **Run:** `dbt build --select "resource_type:seed"`

✅ **Expect:** `Done. PASS=6 WARN=0 ERROR=0 SKIP=0 … TOTAL=6` (2 seeds + 4 tests).

### 2.6 Staging models

📄 **Type:**

1. `mk dbt/models/staging/_sources.yml`
2. `mk dbt/models/staging/stg_nadac__prices.sql`

▶️ **Run:** `dbt show -s stg_nadac__prices --limit 3`

✅ **Expect:** 3 rows with `ndc11`, `nadac_per_unit` as numbers, `pricing_unit`, dates.

📄 **Type:**

3. `mk dbt/models/staging/stg_partd__spending.sql`
4. `mk dbt/models/staging/stg_openfda__products.sql`
5. `mk dbt/models/staging/stg_openfda__packages.sql`

▶️ **Run:** `dbt show -s stg_openfda__packages --limit 3`

✅ **Expect:** `package_ndc_fda` like `0093-5057-98` next to `ndc11` like `00093505798`.

📄 **Type:**

6. `mk dbt/models/staging/_stg_models.yml`

▶️ **Run:** `dbt build -s staging`

✅ **Expect:** `Done. PASS=21 WARN=0 ERROR=0 SKIP=0 … TOTAL=21`

### 2.7 Intermediate models

📄 **Type:**

1. `mk dbt/models/intermediate/int_drug_catalog.sql`

▶️ **Run:** `dbt show -s int_drug_catalog --limit 2`

📄 **Type:**

2. `mk dbt/models/intermediate/int_partd__drug_year.sql`
3. `mk dbt/models/intermediate/int_partd__ndc_crosswalk.sql`
4. `mk dbt/models/intermediate/_int_models.yml`

▶️ **Run:** `dbt build -s intermediate`

✅ **Expect:** `Done. PASS=9 … TOTAL=9`

### 2.8 `dim_drug`

📄 **Type:** `mk dbt/models/marts/dim_drug.sql` and `mk dbt/models/marts/dim_drug.yml`

🧠 **Notice:** why the keys are a **union** of NADAC and FDA NDCs, and the two flags `is_nadac_priced` and `is_in_fda_directory`.

▶️ **Run:** `dbt build -s dim_drug`

✅ **Expect:** `PASS=4 … TOTAL=4`

### 2.9 `fct_nadac_weekly` (plain table version)

📄 **Type:** `mk dbt/models/marts/fct_nadac_weekly.sql` and `mk dbt/models/marts/fct_nadac_weekly.yml`

⚠️ Make sure the reference is at `module-02-dbt-local`. In this module the model is `materialized = 'table'`; Module 3 rewrites it.

▶️ **Run:** `dbt build -s fct_nadac_weekly`

✅ **Expect:** `PASS=6 … TOTAL=6`

### 2.10 Analysis marts

📄 **Type** each `.sql` and its `.yml`:

1. `dbt/models/marts/mart_weekly_price_movers.sql` / `.yml`
2. `dbt/models/marts/mart_brand_generic_spread.sql` / `.yml`
3. `dbt/models/marts/mart_partd_spending_trends.sql` / `.yml`

▶️ **Run:**

```bash
dbt build -s marts
dbt show -s mart_brand_generic_spread
```

✅ **Expect:** `PASS=18 … TOTAL=18`, then 4 brand drugs (Lyrica, Zoloft, Crestor, Lipitor) with brand vs generic prices.

### 2.11 Full build and docs site

▶️ **Run:**

```bash
dbt build
dbt docs generate && dbt docs serve --port 8080
```

✅ **Expect:**
- `Done. PASS=54 WARN=0 ERROR=0 SKIP=0 … TOTAL=54`
- Open port 8080 from the **Ports** tab, then click the lineage-graph button (bottom-right of the docs site): raw → staging → intermediate → marts.

**Ctrl+C** to stop the docs server, then `cd ..`

### ✅ Module 2 done

```bash
cd /workspaces/rx-price-watch
ruff check . && ruff format --check .
cp $REF/docs/02-dbt-local.md docs/
git add -A && git status        # dbt/target, dbt/dbt_packages, include/data must NOT appear (dbt/package-lock.yml may, and that's fine)
git commit -m "Module 2: DuckDB loader and dbt staging, intermediate and star schema"
git tag module-02-dbt-local
git push && git push --tags
```

---

## Module 3 — History & quality

> **Goal:** incremental fact table, SCD2 snapshot, price periods (gaps and islands), unit tests, anomaly tests and a data-quality scorecard.
> **Files:** 10 new + 1 rewritten · **Reference guide:** `docs/03-history-and-quality.md` (read "Concepts" first)

▶️ `refat module-03-history-and-quality && cd dbt`

### 3.1 Rewrite `fct_nadac_weekly` as incremental

📄 **Rewrite:** `code models/marts/fct_nadac_weekly.sql` (you're inside `dbt/`) with `ref dbt/models/marts/fct_nadac_weekly.sql` alongside (the reference now shows the incremental version).

🧠 **Notice:**
- `config(materialized='incremental', unique_key=[...], incremental_strategy='delete+insert')`.
- The **two windows**: `context_days` (read more) and `lookback` (write less). Read the header comment until you can explain why `lag()` needs the context window.

▶️ **Run:**

```bash
dbt build -s fct_nadac_weekly --full-refresh      # first build
dbt build -s fct_nadac_weekly                     # incremental build
dbt compile -s fct_nadac_weekly
grep -c "as_of_date >=" target/compiled/rx_price_watch/models/marts/fct_nadac_weekly.sql
```

✅ **Expect:** `PASS=6` twice, then `2`. Both incremental filters are present in the compiled SQL because the table already exists.

### 3.2 Gaps and islands: price periods

📄 **Type:** `mk dbt/models/intermediate/int_nadac__price_periods.sql` and `mk dbt/models/intermediate/int_nadac__price_periods.yml`

▶️ **Run:** `dbt build -s int_nadac__price_periods`

✅ **Expect:** `PASS=2 … TOTAL=2`

### 3.3 Price history dimension

📄 **Type:** `mk dbt/models/marts/dim_nadac_price_history.sql` and `mk dbt/models/marts/dim_nadac_price_history.yml`

▶️ **Run:**

```bash
dbt build -s dim_nadac_price_history
dbt show --inline "select period_number, nadac_per_unit, valid_from, valid_to, is_current from {{ ref('dim_nadac_price_history') }} where ndc11 = '69238115901' order by period_number"
```

✅ **Expect:** `PASS=2`, then the albuterol inhaler's 5 price periods, including the one-week spike:

```text
| period_number | nadac_per_unit | valid_from |   valid_to | is_current |
|             1 |         1.152… | 2026-05-27 | 2026-07-22 |      False |
|             2 |         1.172… | 2026-07-22 | 2026-08-05 |      False |
|             3 |         1.083… | 2026-08-05 | 2026-09-02 |      False |
|             4 |         8.119… | 2026-09-02 | 2026-09-09 |      False |
|             5 |         1.067… | 2026-09-09 |            |       True |
```

### 3.4 dbt unit tests

📄 **Type:** `mk dbt/models/_unit_tests.yml`

▶️ **Run:** `dbt test --select "test_type:unit"`

✅ **Expect:** `PASS=3 … TOTAL=3`

🧪 **Try this:** in `int_nadac__price_periods.sql`, change the `<> nadac_per_unit` in the `is_new_period` case to `= nadac_per_unit`, then re-run the unit tests.

✅ **Expect:** `FAIL 1 … test_price_periods_split_on_every_change` and `PASS=2 … ERROR=1`. The unit test caught the broken logic before any real data was touched. Change it back and re-run to get `PASS=3`.

### 3.5 Singular tests

📄 **Type:**

1. `mk dbt/tests/singular/assert_no_future_as_of_dates.sql`
2. `mk dbt/tests/singular/assert_price_spikes_reviewed.sql`

▶️ **Run:** `dbt test -s assert_price_spikes_reviewed assert_no_future_as_of_dates`

✅ **Expect:** `PASS=1 WARN=1 … TOTAL=2`. The warning is the spike (2 rows: the jump and the drop back).

### 3.6 Data-quality scorecard

📄 **Type:** `mk dbt/models/marts/mart_data_quality_summary.sql` and `mk dbt/models/marts/mart_data_quality_summary.yml`

▶️ **Run:**

```bash
dbt build -s mart_data_quality_summary
dbt show -s mart_data_quality_summary
```

✅ **Expect:** `PASS=3`, then metric rows including `latest_nadac_as_of_date = 2026-09-23` and `nadac_weeks_loaded = 16`.

### 3.7 SCD2 snapshot of the FDA catalog

📄 **Type:** `mk dbt/snapshots/snap_drug_catalog.yml`

▶️ **Run** the first snapshot:

```bash
dbt snapshot
```

✅ **Expect:** `PASS=1`

Next, simulate a new FDA export in which one labeler was renamed and one product was delisted:

```bash
cd .. && rx-sample-data --with-update && rx-load duckdb && cd dbt
dbt build
dbt show --inline "select ndc11, labeler_name, dbt_valid_to is null as is_current from {{ ref('snap_drug_catalog') }} where ndc11 in ('00378020801','00536322201') order by ndc11, dbt_valid_from"
```

✅ **Expect:** `Done. PASS=66 WARN=1 ERROR=0 SKIP=0 … TOTAL=67`, then:

```text
| 00378020801 | Summit Rx                     | False |   ← old version, closed
| 00378020801 | Summit Rx (a Horizon company) | True  |   ← new current version
| 00536322201 | Acme Generics                 | False |   ← delisted product, closed
```

▶️ **Run** `dbt build` **once more.**

✅ **Expect:** the same result. Re-running is safe.

### ✅ Module 3 done

```bash
cd /workspaces/rx-price-watch
cp $REF/docs/03-history-and-quality.md docs/
git add -A && git status
git commit -m "Module 3: incremental fact, SCD2 snapshot, gaps-and-islands history, unit and anomaly tests"
git tag module-03-history-and-quality
git push && git push --tags
```

---

## Module 4 — Snowflake

> **Goal:** the same pipeline in the cloud. S3 → Snowflake via a storage integration and `COPY INTO`, then dbt on Snowflake.
> **Files:** 8 · **Reference guide:** `docs/04-snowflake.md` (read "Concepts" first)
> ⏱️ **Start your Snowflake trial at the beginning of this module, not earlier.** Trials are time-limited.

▶️ `refat module-04-snowflake`

### Part 1 — Code (no accounts needed)

#### 4.1 The Snowflake loader

📄 **Type:** `mk src/rx_ingest/loaders/snowflake_loader.py`

🧠 **Notice:** `copy_into_sql()` (`MATCH_BY_COLUMN_NAME`, `INCLUDE_METADATA`, `ON_ERROR = ABORT_STATEMENT`), and key-pair authentication in `connect()`.

▶️ **Run:**

```bash
python -c "from rx_ingest.loaders.snowflake_loader import copy_into_sql; print(copy_into_sql('nadac'))"
```

✅ **Expect:** a `COPY INTO RAW.NADAC FROM @RAW.RX_S3_STAGE/nadac/ …` statement.

#### 4.2 The IAM role Snowflake will assume

📄 **Type:** `mk infra/terraform/iam_snowflake.tf`

🧠 **Notice:** the trust policy's placeholder principal and the `sts:ExternalId` condition (read the file's header comment).

▶️ **Run:** `terraform -chdir=infra/terraform validate`

✅ **Expect:** `Success!`

#### 4.3 The Snowflake SQL scripts

📄 **Type** all six into `snowflake/`, reading the comments as you go. You'll run them in Snowsight, not in the terminal:

1. `01_bootstrap.sql`
2. `02_storage_integration.sql`
3. `03_stage_and_file_format.sql`
4. `04_raw_tables.sql`
5. `05_copy_into.sql`
6. `06_explore_and_costs.sql`

### Part 2 — Cloud setup (do the steps exactly in this order)

#### 4.4 Start the Snowflake trial

1. Sign up at signup.snowflake.com. Choose **Enterprise** edition, **AWS**, region **US East (N. Virginia)** (the same region as your bucket).
2. In Snowsight, open your user menu (bottom-left) → your account → **View account details**. Copy the **account identifier** (`ORGNAME-ACCOUNTNAME`).

#### 4.5 Generate the service user's key pair

▶️ **Run:** `make sf-keypair`

✅ **Expect:** a long public key body printed on one line. `include/keys/rsa_key.p8` and `rsa_key.pub` now exist (both git-ignored; confirm with `git status`).

#### 4.6 Bootstrap Snowflake

1. Snowsight → **Projects → Worksheets → + (new SQL worksheet)**.
2. Paste the contents of `snowflake/01_bootstrap.sql`, then replace:
   - `<PASTE_PUBLIC_KEY_BODY_HERE>` → the key body from 4.5
   - `<YOUR_USERNAME>` → your Snowsight login name
3. Click the ▼ next to Run → **Run All**.

✅ **Expect:** the last statement (`DESC USER RX_PIPELINE`) shows an `RSA_PUBLIC_KEY_FP` beginning `SHA256:`.

#### 4.7 Create the IAM role (first apply)

▶️ **Run:**

```bash
terraform -chdir=infra/terraform apply            # Plan: 2 to add → yes
terraform -chdir=infra/terraform output
```

Copy `snowflake_role_arn` and `raw_s3_url` from the output.

#### 4.8 Storage integration + the trust handshake

1. New worksheet → paste `snowflake/02_storage_integration.sql` → fill in the role ARN and the S3 URL (keep the trailing `/`) → **Run All**.
2. In the `DESC INTEGRATION` results, copy **`STORAGE_AWS_IAM_USER_ARN`** and **`STORAGE_AWS_EXTERNAL_ID`**.
3. Edit `infra/terraform/terraform.tfvars`:

   ```hcl
   snowflake_iam_user_arn = "<STORAGE_AWS_IAM_USER_ARN>"
   snowflake_external_id  = "<STORAGE_AWS_EXTERNAL_ID>"
   ```

4. ▶️ Run `terraform -chdir=infra/terraform apply`.

   ✅ **Expect:** `1 to change` (the role's trust policy) → yes.

#### 4.9 Stage and file format

New worksheet → paste `snowflake/03_stage_and_file_format.sql` → fill in the S3 URL → **Run All**.

✅ **Expect:** `LIST @RAW.RX_S3_STAGE` shows the Parquet files you landed in step 1.15.

If you get **Access Denied**: wait a minute (IAM changes take a moment), re-check the tfvars values, and re-run.

#### 4.10 Switch the project to cloud mode

Edit `.env`:

```bash
RX_STORAGE=s3
RX_S3_BUCKET=<bucket_name>
AWS_PROFILE=rx-price-watch
RX_WAREHOUSE=snowflake
DBT_TARGET=snowflake
SNOWFLAKE_ACCOUNT=<ORGNAME-ACCOUNTNAME>
SNOWFLAKE_USER=RX_PIPELINE
SNOWFLAKE_PRIVATE_KEY_PATH=include/keys/rsa_key.p8
```

#### 4.11 Land more data and load it

▶️ **Run:**

```bash
make ingest START=2026-07-01 END=2026-10-01      # ~13 weekly publications → S3 (several minutes)
make ingest-reference                             # Part D + FDA directory → S3
make sf-load                                      # COPY INTO RAW
make sf-load                                      # run it AGAIN
```

✅ **Expect:** the first `sf-load` reports rows loaded per file. The second loads **0**: every file is `LOAD_SKIPPED` because Snowflake's load metadata remembers them.

#### 4.12 dbt on Snowflake

`dbt` doesn't read `.env` by itself, so load it into the terminal first:

▶️ **Run:**

```bash
loadenv
cd dbt
dbt debug --target snowflake
dbt build --target snowflake
cd ..
```

✅ **Expect:** `All checks passed!` then `Done. PASS=… WARN=… ERROR=0`. The same models and tests, now on Snowflake.

With real data, the WARN count reflects real price spikes, which is expected. If a test **fails** on real data, that's a genuine data finding, not a typo. Run `dbt test --target snowflake -s <test_name> --store-failures`, look at the failing rows in Snowsight, and decide whether the data or the test's assumption is wrong. That's great video material.

Explore in Snowsight with `snowflake/06_explore_and_costs.sql`. Check **Admin → Cost management** to see credits used.

#### 4.13 Go back to local mode

Edit `.env` back to:

```bash
RX_STORAGE=local
RX_WAREHOUSE=duckdb
DBT_TARGET=dev
```

Then open a **new terminal**. `loadenv` settings stay in the old terminal until you close it.

### ✅ Module 4 done

```bash
cp $REF/docs/04-snowflake.md docs/
git add -A && git status        # include/keys/ and terraform.tfvars must NOT appear
git commit -m "Module 4: Snowflake setup scripts, storage integration role and COPY INTO loader"
git tag module-04-snowflake
git push && git push --tags
```

---

## Module 5 — Airflow

> **Goal:** the whole pipeline on a weekly schedule in Airflow 3 (Astro CLI + Docker), with dbt rendered as tasks by Cosmos.
> **Files:** 10 · **Reference guide:** `docs/05-airflow.md` (read "Concepts" and "How the pieces fit inside the container" first)

### 5.0 Give the Codespace more memory

Airflow runs several containers. Switch to 4 cores / 16 GB: **Command Palette (Ctrl+Shift+P) → "Codespaces: Change Machine Type" → 4-core**. The Codespace restarts, and your files are kept.

Then:

```bash
cd /workspaces/rx-price-watch
refat module-05-airflow
```

### 5.1 Airflow image files

📄 **Type, in this order:**

1. `mk requirements.txt`: Python packages for Airflow's environment.
2. `mk packages.txt`: leave it empty (it's for OS packages).
3. `mk Dockerfile`: note dbt's **own virtualenv** and `dbt deps` baked into the image.
4. `mk .dockerignore`
5. `mk .astro/config.yaml`
6. `mk docker-compose.override.yml`

### 5.2 The DAG

📄 **Type, in this order:**

1. `mk dags/.airflowignore`
2. `mk dags/rx_common.py`: Slack alerts, the failure callback and the data-health summary.
3. `mk dags/rx_price_watch.py`: the DAG. Read it top to bottom like the architecture diagram.

🧠 **Notice:**
- `CronDataIntervalTimetable` (the Airflow 3 data-interval gotcha).
- `catchup=False` and `max_active_runs=1`.
- Retries plus `on_failure_callback`.
- `ingest_nadac` uses `data_interval_start/end`.
- `DbtTaskGroup` with `InvocationMode.SUBPROCESS`, `TestBehavior.AFTER_EACH`, and unit tests excluded.

▶️ **Run:**

```bash
python -m py_compile dags/rx_common.py dags/rx_price_watch.py && echo compiled
ruff check . && ruff format --check .
```

✅ **Expect:** `compiled`, `All checks passed!`

### 5.3 DAG integrity test

📄 **Type:** `mk tests/test_dag_integrity.py`

▶️ **Run:** `pytest`

✅ **Expect:** `31 passed, 1 skipped`. It's skipped here because Airflow isn't installed in your `.venv`; it really runs inside the container in step 5.7.

### 5.4 Prepare `include/data` for the containers

Airflow's containers run as a different Linux user, so give them write access. Start from an empty data folder, because the DAG will pull **real** data:

▶️ **Run:**

```bash
make clean
mkdir -p include/data && chmod -R a+rwX include/data
```

Confirm `.env` is in local mode (`RX_STORAGE=local`, `RX_WAREHOUSE=duckdb`, `DBT_TARGET=dev`).

### 5.5 Start Airflow

▶️ **Run:** `astro dev start`

The first build takes 5–10 minutes.

✅ **Expect:** a success message with the Airflow UI URL. Open it from the **Ports** tab (8080). Log in with `admin` / `admin` if asked.

### 5.6 Run the DAG

1. Find **rx_price_watch** and toggle it **on**.
2. Click **Trigger** (▶), tick **force_reference_reload**, and click Trigger.
3. Watch the **Graph** view: three ingest tasks → `load_raw` → the `dbt` task group (~35 tasks) → `report`. The first run downloads real Part D and FDA data, so it takes several minutes.
4. Open a dbt task → **Logs** to see the exact `dbt run` / `dbt test` command Cosmos ran.
5. Open `ingest_nadac` → **XCom** to see its summary.
6. Open `report` → **Logs** to see the data-health scorecard.

✅ **Expect:** every task green.

### 5.7 Backfill a few weeks, then test the DAG

▶️ **Run:**

```bash
astro dev run backfill create --dag-id rx_price_watch --from-date 2026-09-03 --to-date 2026-10-01
astro dev pytest tests/test_dag_integrity.py
```

✅ **Expect:** backfill runs appear in the UI and run one after another, in order. The pytest ends with `1 passed`.

### 5.8 Failure drill (retries + alert)

1. In `.env` set `PARTD_DATASET_ID=does-not-exist`, then run `astro dev restart`.
2. Trigger the DAG with **force_reference_reload** ticked.

✅ **Expect:** `ingest_partd` goes to *up_for_retry* twice (the exponential backoff means roughly 15 minutes in total), then *failed*. Its log shows the alert message from `notify_failure` (or it posts to Slack if you've set a webhook). `load_raw` and everything after it shows *upstream_failed*.

3. Set `PARTD_DATASET_ID` back to its original value → `astro dev restart`.

### 5.9 Stop Airflow and clean up

▶️ **Run:**

```bash
astro dev stop
sudo rm -rf include/data        # the containers own these files, hence sudo
```

Switch the machine type back to **2-core** (Command Palette → Change Machine Type) to save Codespace hours.

### ✅ Module 5 done

```bash
cp $REF/docs/05-airflow.md docs/
git add -A && git status        # .astro/config.yaml should be staged; nothing else under .astro/
git commit -m "Module 5: Airflow 3 DAG with Cosmos, Astro project and DAG integrity test"
git tag module-05-airflow
git push && git push --tags
```

---

## Module 6 — CI/CD & monitoring

> **Goal:** automatic checks on every push, a Snowflake deploy button, SQL linting and a volume anomaly check.
> **Files:** 5 · **Reference guide:** `docs/06-ci-and-monitoring.md`

▶️ `refat module-06-ci-and-monitoring`

Rebuild the local sample warehouse first:

```bash
make clean && rx-sample-data --with-update && rx-load duckdb
```

### 6.1 SQL linting

📄 **Type:**

1. `mk dbt/.sqlfluff`
2. `mk dbt/.sqlfluffignore`

▶️ **Run:** `make lint`

✅ **Expect:** ruff `All checks passed!`, then sqlfluff `All Finished!` with no violations listed.

If sqlfluff lists violations in files you typed, run `cd dbt && sqlfluff fix models tests/singular && cd ..`, then `same <file>` to review what changed.

### 6.2 The volume anomaly test

📄 **Type:** `mk dbt/tests/singular/assert_weekly_volume_stable.sql`

▶️ **Run:** `make dbt-deps dbt-build`

✅ **Expect:** `Done. PASS=67 WARN=1 ERROR=0 SKIP=0 … TOTAL=68`

▶️ **Simulate a truncated extract.** Keep only 5 rows of the newest week, then rebuild:

```bash
python - <<'EOF'
import duckdb
c = duckdb.connect("include/data/warehouse/rx_price_watch.duckdb")
c.execute("""delete from raw.nadac
where as_of_date = (select max(as_of_date) from raw.nadac)
  and ndc not in (select distinct ndc from raw.nadac order by ndc limit 5)""")
EOF
cd dbt && dbt build --full-refresh -s fct_nadac_weekly+ ; cd ..
```

✅ **Expect:** `FAIL 1 assert_weekly_volume_stable`, and everything downstream **SKIP**ped. Bad data never reaches the marts.

▶️ **Repair it:**

```bash
make load dbt-build
```

✅ **Expect:** `PASS=67 WARN=1 ERROR=0`

### 6.3 GitHub Actions workflows

📄 **Type:** `mk .github/workflows/ci.yml` / `ref .github/workflows/ci.yml`

⚠️ **Same deliberate difference as the Makefile.** In the *Ruff* step type:

```yaml
      - name: Ruff (lint + format check)
        run: |
          ruff check .
          ruff format --check .
```

📄 **Type:** `mk .github/workflows/snowflake-deploy.yml`

### ✅ Commit, push, and watch CI run

```bash
cp $REF/docs/06-ci-and-monitoring.md docs/
git add -A && git status
git commit -m "Module 6: GitHub Actions CI, Snowflake deploy workflow, SQL lint and volume anomaly check"
git tag module-06-ci-and-monitoring
git push && git push --tags
```

Then:

1. On GitHub, open the **Actions** tab → the **CI** run.

   ✅ **Expect:** two green jobs, *Python — lint & unit tests* and *dbt — build & test on DuckDB* (about 2–4 minutes).

2. Add the badge to the top of your README (commit it on a branch in step 3):

   ```markdown
   [![CI](https://github.com/miltonsuggs/rx-price-watch/actions/workflows/ci.yml/badge.svg)](https://github.com/miltonsuggs/rx-price-watch/actions/workflows/ci.yml)
   ```

3. **Protect `main`:** Settings → Rules → Rulesets → **New branch ruleset**.
   - Target: default branch.
   - Enable **Require a pull request before merging** and **Require status checks to pass**.
   - Add both CI job names as required checks.

   From now on, work on a branch:

   ```bash
   git switch -c add-ci-badge
   # edit README (add the badge) …
   git add -A && git commit -m "Add CI badge" && git push -u origin add-ci-badge
   ```

   Open the pull request on GitHub, wait for green, merge, then:

   ```bash
   git switch main && git pull
   ```

4. **Optional:** Slack alerts (`docs/06-ci-and-monitoring.md` step 6) and the Snowflake deploy secrets (step 7).

---

## Module 7 — Dashboard & ship

> **Goal:** the Streamlit dashboard, the dbt exposure, your final README, and a portfolio-ready repo.
> **Files:** 2 code files + docs · **Reference guide:** `docs/07-dashboard-and-ship.md`

▶️ `refat module-07-ship` (this is the same as `main`, the finished project)

### 7.1 The dashboard

📄 **Type:** `mk dashboard/app.py` / `ref dashboard/app.py`

🧠 **Notice:**
- `get_connection()` works for DuckDB (read-only) or Snowflake.
- One `query()` function for both warehouses, with `?` parameters.
- Caching.
- Each tab is one mart answering one question.

▶️ **Run:** `make dashboard` → open port **8501**.

✅ **Expect:** four KPIs (Latest NADAC publication `2026-09-23`, Drugs priced this week, Price changes this week, Median generic savings) and five working tabs.

**Ctrl+C** to stop it.

### 7.2 The dbt exposure

📄 **Type:** `mk dbt/models/exposures.yml` (put your own name and email in `owner`).

▶️ **Run:**

```bash
make dbt-build
cd dbt && dbt ls -s +exposure:rx_price_watch_dashboard --resource-type model && cd ..
```

✅ **Expect:**
- `Done. PASS=67 WARN=1 ERROR=0 SKIP=0 NO-OP=1 … TOTAL=69`. This matches the reference exactly.
- The list of every model the dashboard depends on.

### 7.3 Final checks

▶️ **Run:**

```bash
make lint && make test
```

✅ **Expect:** `All Finished!` and `31 passed, 1 skipped`.

▶️ **Compare your whole replica with the reference:**

```bash
diff -rq $REF . -x .git -x .venv -x include -x dbt_packages -x target -x logs -x __pycache__ \
  -x .pytest_cache -x .ruff_cache -x '*.egg-info' -x .devcontainer -x .terraform -x '*.tfstate*' \
  -x .terraform.lock.hcl -x package-lock.yml -x .user.yml -x .env -x terraform.tfvars
```

✅ **Expect:** only these lines, all intentional:

```text
Files …/.github/workflows/ci.yml and ./.github/workflows/ci.yml differ     ← lint fix
Files …/Makefile and ./Makefile differ                                     ← lint fix
Files …/README.md and ./README.md differ                                   ← your own README
Only in ./docs: REBUILD.md                                                 ← this guide
```

Anything else (a missing file, or a differing file you can't explain) is a typo to find with `same <file>`.

### 7.4 Write your README and copy the reference docs

1. Copy the reference docs:

   ```bash
   cp $REF/docs/07-dashboard-and-ship.md $REF/docs/data-dictionary.md $REF/docs/troubleshooting.md docs/
   ```

2. Write your final `README.md` **in your own words**, using `ref README.md` as the template: problem → architecture → quickstart → module table → design decisions → testing → cost → next steps → resume bullet. Point the links to your repo, and add your playlist link.

3. Take screenshots of the dashboard, the Airflow graph and the dbt lineage graph. Save them in `docs/images/` and embed them in the README.

### ✅ Module 7 done: ship it

With branch protection on, ship through a pull request:

```bash
git switch -c module-07-ship
git add -A && git commit -m "Module 7: Streamlit dashboard, dbt exposure, final README and reference docs"
git push -u origin module-07-ship
```

Open the pull request → wait for green → merge. Then tag the merged commit:

```bash
git switch main && git pull
git tag module-07-ship && git push --tags
```

Then:

- **Pin** the repo on your GitHub profile.
- Add topics: `data-engineering`, `dbt`, `snowflake`, `airflow`, `terraform`, `healthcare`.
- Add the project to your resume (`docs/07-dashboard-and-ship.md`, step 5).

🎉 **You've rebuilt the whole platform.**

---

## Appendix 1 — Master file checklist

Tick these off as you go. Order matters within each module.

| Module | Order | Files |
|---|---|---|
| A | 1–3 | `.devcontainer/devcontainer.json`, `.devcontainer/post-create.sh`, `docs/REBUILD.md` |
| 0 | 1–7 | `.gitignore`, `LICENSE`, `.env.example`, `pyproject.toml`, `Makefile`*, `.vscode/extensions.json`, `.vscode/settings.json`, `include/README.md`, `README.md` (yours), `docs/00-setup.md` (copied) |
| 1 | 1.1–1.10 | `src/rx_ingest/__init__.py` → `config.py` → `http_client.py` → `storage.py` → `raw.py` → `manifest.py` → `tests/test_raw_and_storage.py` → `ndc.py` → `tests/test_ndc.py` → `sources/__init__.py` → `sources/nadac.py` → `tests/test_nadac.py` → `sources/partd.py` → `sources/openfda_ndc.py` → `tests/test_partd_openfda.py` → `cli.py` → `sample_data.py` |
| 1 | 1.11 | `infra/terraform/`: `versions.tf` → `variables.tf` → `s3.tf` → `iam_ingest.tf` → `budget.tf` → `outputs.tf` → `terraform.tfvars.example` |
| 2 | 2.1–2.2 | `src/rx_ingest/loaders/__init__.py` → `duckdb_loader.py` → `loaders/cli.py` → `tests/test_pipeline_smoke.py` |
| 2 | 2.3–2.5 | `dbt/dbt_project.yml` → `profiles.yml` → `packages.yml` → `macros/generate_schema_name.sql` → `cross_db.sql` → `casting.sql` → `ndc.sql` → `tests/generic/is_valid_ndc11.sql` → `positive_value.sql` → `seeds/*.csv` → `seeds/_seeds.yml` |
| 2 | 2.6–2.10 | `staging/_sources.yml` → `stg_nadac__prices.sql` → `stg_partd__spending.sql` → `stg_openfda__products.sql` → `stg_openfda__packages.sql` → `_stg_models.yml` → `intermediate/int_drug_catalog.sql` → `int_partd__drug_year.sql` → `int_partd__ndc_crosswalk.sql` → `_int_models.yml` → `marts/dim_drug.sql/.yml` → `fct_nadac_weekly.sql/.yml` (table) → `mart_weekly_price_movers` → `mart_brand_generic_spread` → `mart_partd_spending_trends` (.sql/.yml each) |
| 3 | 3.1–3.7 | `fct_nadac_weekly.sql` (rewrite, incremental) → `int_nadac__price_periods.sql/.yml` → `dim_nadac_price_history.sql/.yml` → `models/_unit_tests.yml` → `tests/singular/assert_no_future_as_of_dates.sql` → `assert_price_spikes_reviewed.sql` → `mart_data_quality_summary.sql/.yml` → `snapshots/snap_drug_catalog.yml` |
| 4 | 4.1–4.3 | `src/rx_ingest/loaders/snowflake_loader.py` → `infra/terraform/iam_snowflake.tf` → `snowflake/01…06_*.sql` |
| 5 | 5.1–5.3 | `requirements.txt` → `packages.txt` → `Dockerfile` → `.dockerignore` → `.astro/config.yaml` → `docker-compose.override.yml` → `dags/.airflowignore` → `dags/rx_common.py` → `dags/rx_price_watch.py` → `tests/test_dag_integrity.py` |
| 6 | 6.1–6.3 | `dbt/.sqlfluff` → `dbt/.sqlfluffignore` → `dbt/tests/singular/assert_weekly_volume_stable.sql` → `.github/workflows/ci.yml`* → `.github/workflows/snowflake-deploy.yml` |
| 7 | 7.1–7.4 | `dashboard/app.py` → `dbt/models/exposures.yml` → `README.md` (final, yours) → `docs/07…`, `data-dictionary.md`, `troubleshooting.md` (copied) |

\* = deliberate lint difference from the reference (`ruff check .`).

---

## Appendix 2 — When something doesn't match

1. **Read the error's last lines first.** dbt, pytest and Python all put the useful part at the bottom.
2. **Run `same <file>`** on the file you just typed. Most mismatches are typos: a missing comma in YAML, a wrong indent, a misspelled column.
3. **Check the reference is at the right tag.** `git -C $REF describe --tags` should show the module you're on. The classic mistake is typing `fct_nadac_weekly.sql` in Module 2 while the reference shows the Module 3 version.
4. **Run the same step in the reference.** For example, `cd $REF && make demo`. If it fails there too, it's environmental (network, credentials), not your code.
5. **YAML errors** (`mapping values are not allowed`, `could not find expected ':'`) are almost always indentation. YAML uses spaces, never tabs.
6. **dbt can't find a model or column:** run `dbt parse` from `dbt/`. It validates every file without running anything.
7. **Import errors in Python:** make sure `(.venv)` is in your prompt (`source ~/.bashrc`). If the package itself can't be found, reinstall with `pip install -e ".[s3,dbt,snowflake,dashboard,dev]"`.
8. **More fixes:** `docs/troubleshooting.md` (copied in Module 7; view it any time with `ref docs/troubleshooting.md`).

---

## Appendix 3 — Codespace hours, costs and cleanup

- **Stop the Codespace when you're done for the day.** Use the Codespaces menu (bottom-left) → **Stop Current Codespace**. It also stops itself after 30 idle minutes by default. Your files in `/workspaces` are kept.
- **Free hours are per month** and a 4-core machine uses them twice as fast. Use 2-core except for Module 5. See usage under GitHub → Settings → Billing.
- **After a Codespace rebuild**, the helper commands and the Astro CLI are reinstalled automatically. Re-run `aws configure` (default and `--profile rx-price-watch`), because `~/.aws` lives outside `/workspaces`.
- **AWS:** S3 costs cents. `terraform -chdir=infra/terraform destroy` removes everything when you're finished.
- **Snowflake:** `RX_WH` auto-suspends after 60 seconds, and the resource monitor stops it at 10 credits/month. When the trial ends, run `DROP DATABASE RX_PRICE_WATCH;`.
- **Never commit:** `.env`, `include/keys/`, `include/data/`, `terraform.tfvars`, `*.tfstate`. `git status` before every commit is your safety net.
