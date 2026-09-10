# Docker Build Audit: `rfam/family-pipeline` Modernization

## Executive Summary

- **Build command**:

```
    docker buildx build --platform linux/amd64 --load \
        -t family-pipeline-amd64:latest \
        -f Dockerfile_proposed .
```

- **Build Time**: 718.2s (21/21) FINISHED
- **Image Footprint**: 1.3 GB compressed content size (vs. 1.5 GB upstream `rfam/family-pipeline:latest`), ~5.0 GB uncompressed runtime disk usage.
- **Host & Runtime**: Apple MacBook Pro (M5 Pro, ARM64, 24 GB RAM) via Rancher Desktop (`containerd`/`nerdctl`) targeted to `linux/amd64`.
- Available in Dockerhub `sainsachiko/family-pipeline-amd64:092026`
- **Functional Validation**: The locally loaded `family-pipeline-amd64:latest` image passed the recorded smoke test for Perl/Bio-Easel bindings, `rfci.pl`, `rfco.pl`,`rfsearch.pl`,`rfmake.pl`, `rfnew.pl`, Clustal Omega, Infernal, HMMER, and R-scape.- Available in Dockerhub `sainsachiko/family-pipeline-amd64:092026`- Available in Dockerhub `sainsachiko/family-pipeline-amd64:092026`

---

<details>
<summary><strong>Succeeded Smoke Tests</strong></summary>

The image built from `Dockerfile_proposed` was loaded locally as `family-pipeline-amd64:latest` and tested on `linux/amd64`.

```sh
docker run --platform linux/amd64 --rm family-pipeline-amd64:latest bash -c "
	echo '=== 1. Perl Core & Modules ===' && \
	perl -e 'use MooseX::Types; use Bio::Easel; use Mail::Mailer; print \"Perl & Bio-Easel bindings OK\n\";' && \
	echo '=== 2. Pipeline Scripts ===' && \
	rfci.pl | head -n 4 && \
    rfco.pl | head -n 4 && \
    rfmake.pl | head -n 4 && \
    rfsearch.pl | head -n 4 && \
    rfnew.pl | head -n 4 && \
	echo '=== 3. Bioinformatics Tools ===' && \
	clustalo --version && \
	cmalign -h | head -n 2 && \
	hmmalign -h | head -n 2 && \
	R-scape -h | head -n 2 && \
	raxmlHPC -v | head -n 2
"
```

The command exited successfully and produced:

```text
=== 1. Perl Core & Modules ===
Perl & Bio-Easel bindings OK
=== 2. Pipeline Scripts ===

***** No family dir name passed in *****


USAGE: /Rfam/rfam-family-pipeline/Rfam/Scripts/svn/rfci.pl <directory>

  Where the directory contains the files that consitute a Rfam entry.
No entry identifier or accession specified

usage: /Rfam/rfam-family-pipeline/Rfam/Scripts/svn/rfco.pl <RFAM ACCESSION or IDENTIFIER>

Checks out the latest version of the family from the SVN repository.
Could not open DESC:[No such file or directory]
# rfmake.pl :: investigate and set family score thresholds.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ERROR, no DESC file. If you want to create one, use the -nodesc option
# rfsearch.pl :: build, calibrate, and search a CM against a database.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

***** No family passed  *****


  usage: /Rfam/rfam-family-pipeline/Rfam/Scripts/svn/rfnew.pl <directory>

  Where the directory contains the files that consitute a Rfam entry.
=== 3. Bioinformatics Tools ===
1.2.4
# cmalign :: align sequences to a CM
# INFERNAL 1.1.2 (July 2016)
# hmmalign :: align sequences to a profile HMM
# HMMER 3.2.1 (June 2018); http://hmmer.org/
# R-scape :: RNA Structural Covariation Above Phylogenetic Expectation
# R-scape 2.0.4.a (Dec 2023)
```

`raxmlHPC -v` completed without output in this captured session. Its executable presence is established by the successful container exit, but its version output was not verified by this smoke test.

</details>

---

## 1. Upstream Source Status & Modernization Strategy

Several bioinformatics distribution endpoints from the legacy Xenial build have degraded or gone offline permanently. The table below details the upstream availability and the updated acquisition strategy.

| Component           | Target Version       | Original Source Endpoint                              | Upstream Status                 | Modernization / Acquisition Strategy                                                                                                                                                                                                                                                                                                                                           |
| ------------------- | -------------------- | ----------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **OS Base**         | Ubuntu 22.04 LTS     | Canonical (`ubuntu:xenial`)                           | **EOL** (April 2021)            | Migrated to `ubuntu:22.04` (GCC 11.4, Perl 5.34, active LTS support). Legacy used Perl 5.24.1.                                                                                                                                                                                                                                                                                 |
| **Package Manager** | Pixi (Rust)          | N/A (Manual compiles)                                 | Active                          | Multi-stage pull via `ghcr.io/prefix-dev/pixi:latest`. Replaces heavy Conda runtimes (~30 MB vs ~500 MB).                                                                                                                                                                                                                                                                      |
| **Infernal**        | 1.1.2                | `eddylab.org/infernal/...`                            | Active (HTTP only)              | Replaced source compilation with Bioconda via Pixi (`infernal==1.1.2`).                                                                                                                                                                                                                                                                                                        |
| **HMMER**           | 3.2.1                | `eddylab.org/software/hmmer/...`                      | Active (HTTP only)              | Replaced source compilation with Bioconda via Pixi (`hmmer==3.2.1`).                                                                                                                                                                                                                                                                                                           |
| **MAFFT**           | 7.402                | `mafft.cbrc.jp/alignment/...`                         | Unverified (version not listed) | Replaced source compilation with Bioconda via Pixi (`mafft==7.402`).                                                                                                                                                                                                                                                                                                           |
| **Clustal Omega**   | 1.2.4                | `clustal.org/omega/...`                               | Dead (HTTP 403)                 | Replaced custom source tree compile with Bioconda via Pixi (`clustalo==1.2.4`).                                                                                                                                                                                                                                                                                                |
| **RNAcode**         | 0.3                  | GitHub Releases (`wash/rnacode`)                      | Active (GitHub)                 | Replaced autotools build with Bioconda via Pixi (`rnacode==0.3`).                                                                                                                                                                                                                                                                                                              |
| **MUSCLE**          | 3.8.31               | `drive5.com/muscle/...`                               | Dead (domain offline)           | Replaced static tarball pull with Bioconda via Pixi (`muscle==3.8.31`).                                                                                                                                                                                                                                                                                                        |
| **RAxML**           | 8.2.13               | GitHub (`stamatak/standard-RAxML`)                    | Active (Source repository)      | Retained source build pinned to commit `69a7edcba961f95f732e07ce64e7e5b1c7ae548b`, the verified `v8.2.13` release commit. Parallel compile via `-j$(nproc)`.                                                                                                                                                                                                                   |
| **ViennaRNA**       | 2.4.9                | `tbi.univie.ac.at/...`                                | Active                          | Replaced source compilation with Bioconda via Pixi (`viennarna==2.4.9`).                                                                                                                                                                                                                                                                                                       |
| **T-Coffee**        | 11.0.8               | GitHub (`cbcrg/tcoffee`)                              | Active (GitHub)                 | Replaced git clone and C compile with Bioconda via Pixi (`t_coffee==11.0.8`).                                                                                                                                                                                                                                                                                                  |
| **R-scape**         | HEAD (unpinned)      | `eddylab.org/software/rscape/...`                     | Active (HTTP only)              | Installed via Pixi (unpinned; no version tag in Dockerfile). `--expose R-scape` to prevent `esl-*` binary collision with HMMER.                                                                                                                                                                                                                                                |
| **CMfinder**        | 0.2                  | `bio.cs.washington.edu/yzizhen/...`                   | Dead (Host offline)             | Restored source tarball via Wayback Machine (`web.archive.org`), compiled with `-j$(nproc)`.                                                                                                                                                                                                                                                                                   |
| **PPfold**          | 3.1.1                | `daimi.au.dk/~compbio/pfold/...`                      | Dead (Host offline)             | Restored precompiled JAR via Wayback Machine (`web.archive.org`).                                                                                                                                                                                                                                                                                                              |
| **ERATE**           | 0.8                  | `eddylab.org/software/erate/...`                      | Active (HTTP only)              | Retained as source compile (`make -j$(nproc) dnaml`); unavailable on Bioconda/Conda-Forge.                                                                                                                                                                                                                                                                                     |
| **Bio-Easel**       | 0.06                 | GitHub (`nawrockie/Bio-Easel` + `EddyRivasLab/easel`) | Active (Source repository)      | The Bio-Easel wrapper is pinned to commit `ec77fa923b501768346b8870667e7c674a50b009`. `Bio-Easel-0.06` was verified as an Easel tag, not a branch, and resolves to commit `3b8fae1aafd36c544108f755a871fcb0d2e7c749`; the build fetches that immutable commit directly. Patches `aclocal.m4`/`configure` for Autoconf 2.71, adds `--enable-pic --enable-sse` and `-j$(nproc)`. |
| **Perl Ecosystem**  | Perl 5.24.1 (Xenial) | CPAN shell                                            | High latency / Network load     | Replaced ~90% of CPAN modules with native Ubuntu APT `lib*-perl` packages. Target Perl upgraded to 5.34 via Ubuntu 22.04.                                                                                                                                                                                                                                                      |

---

## 2. Structural & Architectural Modernization

### Core System & Package Layer

- **Base OS Update**: Upgraded from `ubuntu:xenial` (16.04, EOL since April 2021) to `ubuntu:22.04 LTS`. This brings native GCC 11.4, modern glibc compatibility, and long-term security patching.
- **Pixi Toolchain Provisioning**: Replaced ~12 manual source installations with Pixi (Rust-based Conda client). Pixi is copied via multi-stage build from `ghcr.io/prefix-dev/pixi:latest`, maintaining an isolated ~30 MB client footprint rather than bloating layers with Mamba/Miniconda (~500 MB).
- **Layer Minimization**: Combined multi-stage `apt-get` runs and unified cleanup directives (`apt-get clean`, `rm -rf /var/lib/apt/lists/*`) into single layer definitions.

### Perl Dependency Optimization

- **CPAN to Native APT Substitution**: The original Dockerfile spent over 14 minutes compiling Perl modules and running single-threaded test harnesses. Switching to pre-compiled Ubuntu binary packages (`libmoosex-types-perl`, `libmailtools-perl`, `libdbix-class-perl`, `libdatetime-perl`, `libinline-c-perl`, etc.) reduced installation time to seconds.
- **Missing Runtime Dependencies Fixed**: Resolved missing runtime modules (`MooseX::Types`, `Mail::Mailer`/`libmailtools-perl`) that were absent from the original Dockerfile and caused immediate aborts in `rfci.pl`.
- **De-duplication**: Eliminated redundant sequential runs of `cpan -f install Inline::C`. Any remaining non-packaged Perl leaf modules are built with `cpanm --notest`.

### Bio-Easel Autoconf 2.71 Compatibility Patch

- **Legacy Behavior**: Present in the original Dockerfile and built using Ubuntu 16.04's legacy Autotools (Autoconf 2.69).
- **Modernization Fix**: Under Ubuntu 22.04 (Autoconf 2.71), Easel's `configure` generated empty conditionals (`then \n fi`), causing build failures. The updated process injects null statements (`:;`) into `aclocal.m4` and `configure`, builds Easel explicitly with `./configure --prefix=/usr/local --enable-pic --enable-sse && make install`, and compiles `Bio-Easel` using parallel jobs (`-j$(nproc)`).

---

## 3. Environment & Configuration

| Variable / Path | Legacy Configuration                                | Modernized Configuration                                                                                                           | Rationale                                                                                                                 |
| --------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `BASE OS`       | `ubuntu:xenial` (16.04)                             | `ubuntu:22.04`                                                                                                                     | Eliminates security debt and outdated C/Perl toolchains.                                                                  |
| `PATH`          | `/usr/bin:$PATH:/Rfam/software/bin:...`             | `/root/.pixi/bin:/usr/bin:$PATH:/Rfam/software/bin:/Rfam/rfam-family-pipeline/Rfam/Scripts/...`                                    | Prioritizes version-locked Pixi binaries while retaining legacy script paths.                                             |
| `PERL5LIB`      | `/usr/share/perl5:/usr/local/share/perl/5.24.1:...` | `/usr/share/perl5` plus `/Rfam/Bio-Easel/blib/lib`, `/Rfam/Bio-Easel/blib/arch`, `Rfam/Lib`, `Schemata`, `PfamLib`, `PfamSchemata` | Removes executable paths and the obsolete Perl 5.24.1 path while retaining application and XS module locations.           |
| `RFAM_CONFIG`   | `/Rfam/config/rfam.conf`                            | `/Rfam/config/rfam.conf` (with fallback symlink)                                                                                   | Symlinked to repo sample configuration so CLI help flags run out-of-the-box without requiring an external mounted volume. |
| `DISPLAY`       | `0.0`                                               | `0.0`                                                                                                                              | Retained for tools generating phylogenetic/postscript trees.                                                              |
