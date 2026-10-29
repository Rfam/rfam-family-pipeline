# Developer Reference

This is the **Rfam family-building pipeline** — a Perl-based bioinformatics system for building, curating, quality-checking, and publishing Rfam family annotations. Rfam is a database of RNA families represented by multiple sequence alignments and covariance models (CMs).

---

## Directory Structure

```
.
├── Rfam/                            # Core pipeline code
│   ├── Conf/                        # Configuration files
│   ├── Lib/Bio/Rfam/               # Perl module library
│   ├── Schemata/                   # DBIx::Class schema modules
│   ├── Scripts/                    # Entry-point scripts (organized by phase)
│   │   ├── make/                   # Build families
│   │   ├── qc/                     # Quality control
│   │   ├── curation/               # Alignment and structural annotation
│   │   ├── view/                   # Generate web-viewable family pages
│   │   ├── export/                 # Export data
│   │   ├── ci/                     # CI build scripts
│   │   ├── svnhooks/               # SVN post-commit hooks
│   │   └── ...
│   ├── Tests/                      # Test infrastructure
│   └── DatabaseModel/              # DBIC schema definition (rfamlive.mwb)
├── PfamLib/                        # Shared Pfam/TreeFam libraries (legacy)
├── PfamSchemata/                   # DBIx::Class schema modules (legacy)
├── kubernetes/                     # K8s deployment
├── dependencies/                   # Supporting R scripts
├── docs/                           # This documentation
├── .github/workflows/              # GitHub Actions
├── Dockerfile                      # Original Dockerfile (Ubuntu Xenial)
├── Dockerfile_proposed             # Modernized Dockerfile (Ubuntu 22.04, Pixi)
└── DOCKER-BUILD-AUDIT.md           # Docker build audit report
```

---

## Core Perl Modules

### `Rfam/Lib/Bio/Rfam/`

| Module | Responsibility |
|---|---|
| `Config.pm` | Loads and parses `rfam.conf` via `Config::General` |
| `Family.pm` | Container for an Rfam family (accessor object) |
| `Family/MSA.pm` | Multiple sequence alignment handling |
| `FamilyIO.pm` | Read/write family files (SEED, CM, DESC, ALIGN, etc.) |
| `Infernal.pm` | Wrapper for Infernal CM commands |
| `SeqDB.pm` | Sequence database access |
| `QC.pm` | Quality control logic |
| `Clan.pm`, `ClanIO.pm` | Family clan management |
| `Motif.pm`, `MotifIO.pm` | Motif handling |
| `SS.pm` | Secondary structure data |
| `PredictSS.pm` | RNA secondary structure prediction |
| `AlignMethods.pm` | Coordination of alignment tools (MAFFT, MUSCLE, T-Coffee, ClustalW) |
| `View.pm` | Web view generation |
| `SunburstFactory.pm` | Sunburst visualization data |
| `GOA/` | Gene Ontology annotation |
| `HtmlAlignment.pm` | HTML alignment rendering |
| `SVN/Client.pm` | SVN client wrapper for family checkout |
| `Utils.pm` | General utilities |

### Database Schemas

The pipeline uses **DBIx::Class** for database access. Two parallel schema trees exist:

- **`Rfam/Schemata/`** — Current schema (RfamDB, RfamJobs, RfamLive)
- **`PfamSchemata/`** — Legacy schema (RfamDB, PfamDB, iPfamDB, WebUser, WikiApprove)

The database model is defined in `Rfam/DatabaseModel/rfamlive.mwb` (MySQL Workbench).

---

## Pipeline Scripts (Entry Points)

All scripts are executable Perl programs, organized by pipeline phase. They are added to `$PATH` in the Dockerfile.

### Building Families (`Rfam/Scripts/make/`)

| Script | What it does |
|---|---|
| `rfsearch.pl` | Search sequences against CMs using Infernal |
| `rfmake.pl` | Process search results, set model thresholds (GA), build representative alignments |
| `rfseed.pl` | Add/remove sequences from a family SEED alignment |
| `rfmatch.pl` | Match sequences to existing families |
| `rfreplace.pl` | Replace sequences in alignments |
| `rfseed-extend.pl` | Extend seed alignments |
| `rfnew.pl` | Create a new family from scratch |

### Quality Control (`Rfam/Scripts/qc/`)

| Script | What it does |
|---|---|
| `rqc-all.pl` | Run all QC checks on a family |
| `rqc-check.pl` | Core QC validation |
| `rqc-CM.pl` | Covariance model checks |
| `rqc-format.pl` | File format validation |
| `rqc-overlap.pl` | Check family overlaps |
| `rqc-seqs.pl` | Sequence-level QC |
| `rqc-seqs_coding.pl` | Coding-sequence specific QC |
| `rqc-spell.pl` | Spelling/description checks |
| `rqc-ss-cons.pl` | Secondary structure consistency |

### Curation (`Rfam/Scripts/curation/`)

| Script | What it does |
|---|---|
| `align_and_ss.pl` | Run alignment methods + secondary structure prediction |
| `create_alignment.pl` | Build alignments from sequences |
| `collateSeq.pl` | Collect sequences |
| `predict_ss.pl` | Predict RNA secondary structure |
| `add_ref.pl` | Add literature references |
| `pfetch` | Fetch sequences |
| `tblout2bigBed.pl` | Convert tblout to BigBed format |

### Web Views (`Rfam/Scripts/view/`)

| Script | What it does |
|---|---|
| `rfam_family_view.pl` | Generate web-viewable family page |
| `rfam_clan_view.pl` | Generate clan page |
| `job_dequeuer.pl` | Poll for pending view-generation jobs |
| `make_sunburst.pl` | Generate sunburst chart data |
| `populate_tax_tree_table.pl` | Build taxonomy tree |
| `create-ss-graphics.pl` | Create secondary structure graphics |

---

## Docker Setup

Multiple Dockerfiles support different deployment targets:

| File | Base | Purpose |
|---|---|---|
| `Dockerfile` | `ubuntu:xenial` | Original production (Perl 5.24, static binary builds) |
| `Dockerfile_proposed` | `ubuntu:22.04` | Modernized build using Pixi for R, GCC 11.4 |

### Bioinformatics Tools Included

- **Infernal** — CM build/search/calibrate
- **HMMER** — hmmbuild, hmmsearch, hmmalign
- **MAFFT** — Multiple sequence alignment
- **MUSCLE** — Multiple sequence alignment
- **T-Coffee** — Multiple sequence alignment
- **Clustal Omega** — Multiple sequence alignment
- **RNAcode** — Coding potential assessment
- **RAxML** — Phylogenetic tree building
- **ViennaRNA** — RNAfold for secondary structure
- **R-scape** — RNA statistical coupling analysis

---

## Perl Dependencies

| Module | Purpose |
|---|---|
| `Moose`, `MooseX::NonMoose`, `MooseX::Types` | OOP framework |
| `Bio::Easel` | Infernal's Perl binding |
| `DBIx::Class` | ORM for database access |
| `Config::General` | Config file parser |
| `Catalyst` | Web framework |
| `Inline::C`, `Inline` | Embed C in Perl |
| `Data::Printer`, `Data::UUID` | Debugging utilities |
| `JSON`, `XML::LibXML` | Data serialization |
| `IPC::Run` | Process management |
| `DateTime`, `DateTime::Format::MySQL` | Date/time handling |

---

## Development Workflow

### Local Docker Development

```bash
# Build the image
docker build -t rfam-local -f Dockerfile .

# Run the container
# The code is already inside the image — only mount a workdir for your results
docker run -it --rm \
  -v ~/rfam-work:/workdir \
  -e RFAM_CONFIG=/Rfam/rfam-family-pipeline/Rfam/Conf/rfam.conf \
  rfam-local \
  bash
```

### Running Tests

```bash
cd Rfam/Tests
prove *.t
```

Or run specific tests:

```bash
prove bio_rfam_config.t
prove rfmake.t
```

### CI/CD

GitHub Actions workflows in `.github/workflows/`:
- `test.yml` — Lint, build Docker/Singularity images, run tests
- `main.yaml` — Build Docker image, push to Docker Hub, convert to Singularity

---

## Important Notes

- Config file format is XML-style (`Config::General`), not YAML or JSON.
- Family data is version-controlled in SVN at `https://svn.rfam.org/svn/data_repos/`.
- `Bio::Rfam::Config` loads the config and exposes database connections via `RfamLive` and `RfamJobs` schema objects.
- Legacy `PfamSchemata` modules should be considered deprecated in favor of `Rfam/Schemata`.
- The original `Dockerfile` uses Ubuntu Xenial (16.04) which is EOL.
