# Configuration Guide

The Rfam pipeline uses XML-style config files loaded via Perl's `Config::General`. Every run requires two environment variables and a properly configured config file.

## Environment Variables

```bash
export RFAM_CONFIG=/path/to/rfam.conf
export PERL5LIB=/path/to/rfam-family-pipeline/Rfam/Lib:/path/to/rfam-family-pipeline/Rfam/Schemata:/path/to/rfam-family-pipeline/PfamLib:/path/to/rfam-family-pipeline/PfamSchemata
```

| Variable | Purpose |
|---|---|
| `RFAM_CONFIG` | Path to the main config file (`rfam.conf`) |
| `PERL5LIB` | Colon-separated list of directories where Perl finds the pipeline modules |

## Config Merging

The pipeline loads the main config, then looks for a file with `_local.conf` appended in the same directory. If found, it merges the local file on top, overriding only the settings you specify.

```
Rfam/Conf/rfam.conf              ← master template (committed to repo)
Rfam/Conf/rfam_local.conf        ← your overrides (ignored by git)
```

## Available Config Files

| File | Use case |
|---|---|
| `Rfam/Conf/rfam.conf` | Production (EBI HPC, SLURM scheduler) |
| `Rfam/Conf/rfam_cloud.conf` | Cloud environment |
| `Rfam/Conf/rfam_jfrc.conf` | Janelia Farm (HHMI) deployment |
| `Rfam/Conf/rfam_local.conf` | Local dev (MySQL connection) |

---

## Config Reference

### `location`

Identifies the deployment environment.

```xml
location EBI          # Valid values: EBI, JFRC, CLOUD, or "" for local/dev
```

### `<svn>` — Version Control

| Field | Description | Default/Example |
|---|---|---|
| `svnNewFamilies` | SVN path for new families pending review | `trunk/FamiliesPending` |
| `svnFamilies` | SVN path for approved families | `trunk/Families` |
| `svnNewClans` | SVN path for new clans pending review | `trunk/ClansPending` |
| `svnClans` | SVN path for approved clans | `trunk/Clans` |
| `svnRevision` | SVN revision tag | `HEAD` |
| `svnRepos` | Root URL of the data repository | `https://svn.rfam.org/svn/data_repos/` |

### `<binaries>` — Tool Locations

| Field | Description |
|---|---|
| `infernal` | Path to Infernal binary directory (`cmsearch`, `cmcalibrate`, `cmbuild`, etc.) |
| `easel` | Path to Easel binary directory (`essearch`, `estext`, etc.) |
| `binLocation` | General binary path used by scripts |

### `<seqdb>` — Sequence Database

#### `<rfamseq>` section

| Field | Description |
|---|---|
| `dbSize` | Total size of the sequence database in base pairs (used for E-value calculation) |
| `dbPath` | Path to the full FASTA file |
| `fetchPath` | Path used for sequence retrieval (same as `dbPath`) |
| `searchPathPrefix` | Prefix for split search files (for parallel searching) |
| `searchPathSuffix` | Suffix for split search files (usually `.fa.gz`) |
| `revMate` | Name of the reversed complement database |
| `haveTax` | Whether taxonomy data is available (`0` or `1`) |
| `updateDesc` | Whether to update family descriptions (`0` or `1`) |
| `nSearchFiles` | Number of split search files to use for parallelization |

#### `<revrfamseq>` section

| Field | Description |
|---|---|
| `dbSize` | Size of the reversed database |
| `searchPathPrefix` | Prefix for reversed search files |
| `searchPathSuffix` | Suffix for reversed search files |
| `nSearchFiles` | Number of split search files |

### `<Model>` — Database Connection

| Field | Description |
|---|---|
| `host` | MySQL server hostname or IP |
| `port` | MySQL port |
| `database` | Database name |
| `user` | Read-only database user |
| `password` | Password for the read-only user |
| `adminuser` | Admin user (for schema changes) |
| `adminpassword` | Password for the admin user |

### `<files>` — File Management

#### `family_file` — Required family files (in order)

| File | Description |
|---|---|
| `SEED` | Seed alignment (Stockholm format) |
| `CM` | Covariance model (Infernal format) |
| `TBLOUT` | CMsearch tblout results |
| `REVTBLOUT` | Reverse complement search results |
| `SEEDTBLOUT` | Seed alignment tblout |
| `SCORES` | CMsearch scores |
| `SEEDSCORES` | Seed alignment scores |
| `DESC` | Family description file |

#### `excluded_file` — Files to skip in SVN

| File | Description |
|---|---|
| `TBLOUT` | Search results are not stored permanently |

#### `timestamp_ordered_file` — Files needing timestamp fixes after checkout

`SEED`, `HMM`, `OUTPUT`, `DFAMOUT`, `OUTPUT.rev`, `DFAMOUT.rev`, `scores`, `ALIGN`, `DESC`

### `<curation>` — Quality Control and Annotation

| Setting | Description |
|---|---|
| `dictionary` | Path to a spelling dictionary file |

#### `<RNAcode>` section

| Field | Description | Default |
|---|---|---|
| `pvalue` | P-value threshold for RNAcode significance | `0.05` |

#### `<descTypes>` section — Gene type ontology

Valid gene types for family descriptions:

- **Gene**: `tRNA`, `rRNA`, `miRNA`, `ribozyme`, `antisense`, `antitoxin`, `lncRNA`, `CRISPR`, `sRNA`, `snRNA` (with subtypes `splicing`, `snoRNA` with `CD-box`/`HACA-box`/`scaRNA`)
- **Cis-reg**: `IRES`, `riboswitch`, `thermoregulator`, `frameshift_element`, `leader`
- **Other**: `Intron`

#### `<overlap>` — Families allowed to overlap during overlap QC

```xml
<overlap>
  RF00001
  RF00004
</overlap>
```

#### `<ignorableQC>` — QC checks that can be suppressed

| Check | What it validates |
|---|---|
| `overlap` | Overlap between families |
| `spell` | Spelling/description quality |
| `coding` | Coding potential assessment |
| `seed` | Seed alignment quality |
| `missing` | Missing required files |
| `length` | Sequence length checks |
| `seedrf` | Seed reverse complement checks |

#### Suggestion URLs

```xml
SOsuggestions "http://www.sequenceontology.org/cgi-bin/miso.cgi"
GOsuggestions "http://www.geneontology.org/ or http://www.ebi.ac.uk/QuickGO/"
```

### `<view_sets>` — Web View Generation

| Setting | Components |
|---|---|
| `rfamseq` | `Alignment`, `Species`, `SecondaryStructure`, `Tree` |
| `genome` | `Search`, `Tree` |
| `family` | `HtmlAlignment`, `Species`, `Pseudoknots`, `SecondaryStructure`, `Tree`, `PDB`, `Motifs`, `Sunburst` |

### `<view_process_job_dequeuer>` — Job Queue Settings

| Field | Description | Default |
|---|---|---|
| `polling_interval` | Seconds between job queue checks | `2` |
| `lock_dir` | Directory for job lock files | `/tmp` |
| `tmp_dir` | Temporary directory for view generation | `/tmp` |
| `tmp_space` | Disk space in MB required for job execution | `100` |
| `lsf_queue` | LSF job queue name | `research` |
| `lsf_user` | LSF username | `rfamprod` |

### Global Settings

| Setting | Description |
|---|---|
| `binLocation` | Top-level binary directory |
| `RPlotScript` | Path to R plotting script |
| `Stockholm2ArcScript` | Path to Stockholm-to-Arc conversion script |
| `productionPath` | Base path for production outputs |
| `ssImages` | Directory for secondary structure images |
| `scheduler` | Job scheduler (`slurm` or `lsf`) |
