# Testing Guide

## Overview

21 test files covering 355 individual test assertions for family parsing, alignment, QC, and database-backed features.

### Test file reference

| File | Tests | What it validates |
|---|---|---|
| `bio_rfam_clan_desc.t` | 1 | Clan DESC file parsing |
| `bio_rfam_config.t` | 1 | Config file loading and parsing |
| `bio_rfam_family.t` | 1 | Family object creation and accessors |
| `bio_rfam_family_cm.t` | 1 | Covariance model (CM) file parsing |
| `bio_rfam_family_desc.t` | 1 | Family DESC file parsing |
| `bio_rfam_familyio.t` | 1 | Family file read/write (SEED, CM, DESC, ALIGN) |
| `bio_rfam_family_scores.t` | 1 | CMsearch SCORES file parsing |
| `bio_rfam_family_tblout.t` | 1 | Infernal tblout search results parsing |
| `bio_rfam_family_msa.t` | 8 | MSA sequence bit-score and species lookup from DB |
| `bio_rfam_htmlalignment.t` | 14 | HTML alignment rendering with DB-backed regions |
| `bio_rfam_infernal.t` | 1 | Infernal CM command wrapper |
| `bio_rfam_pair.t` | 1 | Pairwise sequence comparison |
| `bio_rfam_qc.t` | 1 | Quality control rules |
| `bio_rfam_seqdb.t` | 1 | Sequence database access |
| `bio_rfam_ss.t` | 1 | RNA secondary structure handling |
| `bio_rfam_svn_client.t` | 1 | SVN checkout client |
| `bio_rfam_svn_commit.t` | 1 | SVN commit operations |
| `bio_rfam_view.t` | 1 | Web viewable page generation |
| `rfmake.t` | 22 | Build families from search results, set CM thresholds |
| `rfmatch.t` | 20 | Match sequences against existing families |
| `rfseed-extend.t` | 158 | Extend seed alignments |

### Test data

| Data directory | Contents |
|---|---|
| `Rfam/Tests/data/RF00006` | Vault RNA (complete family) |
| `Rfam/Tests/data/RF00014` | 5S rRNA (complete family) |
| `Rfam/Tests/data/lncRNAGood` | Valid lncRNA test case |
| `Rfam/Tests/data/lncRNABad` | Invalid lncRNA test case |
| `Rfam/Tests/data/rfmatch` | rfmatch test data |
| `Rfam/Tests/data/rfseed-extend` | rfseed-extend test data |
| `Rfam/Tests/data/setup_test_db.sql` | MySQL test database schema |
| `Rfam/Tests/data/test.cm` | Test covariance model |

---

## 1. Build the Docker Image

```bash
docker build --platform linux/amd64 -t family-pipeline:test -f Dockerfile .
```

---

## 2. Docker

### 2.1 Initialize test database

Start a test MySQL container and load seed data:

```bash
# 1. Clean up stale container
docker rm -f rfam-test-mysql 2>/dev/null || true

# 2. Start MySQL on port 3307
docker run -d --name rfam-test-mysql \
  -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=testpass \
  -e MYSQL_DATABASE=rfam_test \
  -e MYSQL_USER=rfamro \
  -e MYSQL_PASSWORD=testpass \
  mysql:8.0 \
  --default-authentication-plugin=mysql_native_password

# 3. Wait for MySQL to be ready
sleep 10
docker exec -i rfam-test-mysql mysqladmin ping -u root -ptestpass --silent 2>/dev/null && echo "MySQL is ready."

# 4. Load test data
docker exec -i rfam-test-mysql mysql -u root -ptestpass rfam_test \
  < Rfam/Tests/data/setup_test_db.sql

# 5. Verify data loaded
docker exec -i rfam-test-mysql mysql -u root -ptestpass rfam_test -e '
  SELECT "taxonomy" AS tbl, COUNT(*) FROM taxonomy
  UNION ALL SELECT "rfamseq", COUNT(*) FROM rfamseq
  UNION ALL SELECT "family", COUNT(*) FROM family
  UNION ALL SELECT "full_region", COUNT(*) FROM full_region
  UNION ALL SELECT "seed_region", COUNT(*) FROM seed_region;
'
```

Expected output:

| tbl | cnt |
|---|---|
| taxonomy | 34 |
| rfamseq | 34 |
| family | 2 |
| full_region | 34 |
| seed_region | 29 |

### 2.2 Run tests

MySQL runs on port **3307**. The config file uses `host.docker.internal` which must be replaced with `127.0.0.1` via `sed`.

Run from the repo root:

```bash
docker run --platform linux/amd64 --network host --rm \
  -w /Rfam/rfam-family-pipeline/Rfam/Tests \
  family-pipeline:test \
  bash -c '
    # Set up config (path inside the image)
    mkdir -p /Rfam/config
    sed "s/host\.docker\.internal/127.0.0.1/g" \
      /Rfam/rfam-family-pipeline/Rfam/Tests/rfam_test.conf \
      > /Rfam/config/rfam_test.conf

    # Run tests
    RFAM_CONFIG=/Rfam/config/rfam_test.conf prove --jobs=1 *.t
  '
```

---

## 3. Singularity

Singularity does not support `--network host`. On HPC systems (no Docker), run MySQL as a rootless Singularity instance — it pulls the MySQL image directly from Docker Hub via Singularity's `docker://` URI, no Docker install needed.

### 3.1 Initialize test database (rootless)

```bash
# Set runtime paths in user-writable space
DB_DIR="/tmp/rfam_mysql_${USER}"
mkdir -p "${DB_DIR}/data" "${DB_DIR}/run"

# 1. Initialize MySQL data directory (only needs to run once)
singularity exec \
  --bind "${DB_DIR}/data:/var/lib/mysql" \
  --bind "${DB_DIR}/run:/var/run/mysqld" \
  docker://mysql:8.0 \
  mysqld --initialize-insecure --user=$(id -u)

# 2. Start MySQL background instance on port 3307
singularity instance start \
  --bind "${DB_DIR}/data:/var/lib/mysql" \
  --bind "${DB_DIR}/run:/var/run/mysqld" \
  docker://mysql:8.0 \
  rfam-db \
  mysqld \
    --port=3307 \
    --user=$(id -u) \
    --default-authentication-plugin=mysql_native_password

# 3. Wait until MySQL accepts queries
echo "Waiting for Singularity MySQL..."
until singularity exec instance://rfam-db mysqladmin ping -h 127.0.0.1 -P 3307 -u root --silent; do
  sleep 2
done

# 4. Bootstrap user and load seed data
singularity exec instance://rfam-db mysql -h 127.0.0.1 -P 3307 -u root -e "
  CREATE DATABASE IF NOT EXISTS rfam_test;
  CREATE USER IF NOT EXISTS 'rfamro'@'%' IDENTIFIED WITH mysql_native_password BY 'testpass';
  GRANT ALL PRIVILEGES ON rfam_test.* TO 'rfamro'@'%';
  FLUSH PRIVILEGES;
"

singularity exec instance://rfam-db mysql -h 127.0.0.1 -P 3307 -u root rfam_test \
  < Rfam/Tests/data/setup_test_db.sql

# 5. Verify data loaded
singularity exec instance://rfam-db mysql -h 127.0.0.1 -P 3307 -u root rfam_test -e '
  SELECT "taxonomy" AS tbl, COUNT(*) FROM taxonomy
  UNION ALL SELECT "rfamseq", COUNT(*) FROM rfamseq
  UNION ALL SELECT "family", COUNT(*) FROM family
  UNION ALL SELECT "full_region", COUNT(*) FROM full_region
  UNION ALL SELECT "seed_region", COUNT(*) FROM seed_region;
'
```

### 3.2 Run tests

The config file already uses `127.0.0.1` (MySQL runs in the same host namespace via Singularity instance), so use it as-is:

```bash
singularity exec \
  --pwd /Rfam/rfam-family-pipeline/Rfam/Tests \
  --bind $(pwd):/Rfam/rfam-family-pipeline:ro \
  family-pipeline.sif \
  bash -c '
    RFAM_CONFIG=/Rfam/rfam-family-pipeline/Rfam/Tests/rfam_test.conf prove --jobs=1 *.t
  '
```

### 3.3 Clean up

```bash
singularity instance stop rfam-db
rm -rf "${DB_DIR}"
```

---

## 4. Run Individual Tests

```bash
cd Rfam/Tests

# Configuration module tests
prove bio_rfam_config.t

# Family I/O tests
prove bio_rfam_familyio.t

# rfmake.pl functional test
prove rfmake.t

# rfmatch.pl functional test
prove rfmatch.t

# QC module tests
prove bio_rfam_qc.t
```

---

## 5. GitHub Actions

Tests also run automatically on pull requests and pushes to `master`:

- **Docker tests** — builds the image, runs `prove *.t` inside Docker with a MySQL service container
- **Singularity tests** — builds the SIF image, runs `prove *.t` inside Apptainer with a rootless MySQL instance

See `.github/workflows/test.yml` for the CI configuration.
