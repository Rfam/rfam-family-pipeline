# Rfam family pipeline Docker image
# Base: ubuntu:22.04 (GCC 11.4 — compatible with older bioinformatics tools)
FROM ghcr.io/prefix-dev/pixi:0.83.0-jammy AS pixi-provider
FROM ubuntu:22.04

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# ── System dependencies & Pre-compiled Perl libraries ─────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get install -y --no-install-recommends \
    aspell \
    aspell-en \
    locales \
    automake \
    cpanminus \
    curl \
    default-jdk \
    fort77 \
    g++ \
    gcc \
    gfortran \
    git \
    gzip \
    less \
    libbio-perl-perl \
    libcatalyst-action-renderview-perl \
    libcatalyst-perl \
    libconfig-general-perl \
    libconvert-color-perl \
    libdata-pageset-perl \
    libdata-printer-perl \
    libdata-uuid-perl \
    libdatetime-format-mysql-perl \
    libdatetime-perl \
    libdbd-mysql-perl \
    libdbix-class-perl \
    libexpat1-dev \
    libfile-sharedir-install-perl \
    libfile-slurp-perl \
    libfile-touch-perl \
    libimage-size-perl \
    libinline-c-perl \
    libinline-perl \
    libio-all-perl \
    libio-string-perl \
    libipc-run-perl \
    libjson-perl \
    liblog-log4perl-perl \
    libmailtools-perl \
    libmunge2 \
    libmoosex-nonmoose-perl \
    libmoosex-types-loadableclass-perl \
    libmoosex-types-perl \
    libmoosex-types-structured-perl \
    libsearch-queryparser-perl \
    libsvn-perl \
    libsvn-look-perl \
    libterm-readpassword-perl \
    libtest-most-perl \
    libtext-diff-perl \
    libx11-6 \
    libxml-libxml-perl \
    libxml-simple-perl \
    libxml2 \
    libxml2-dev \
    make \
    perl \
    r-base \
    r-base-dev \
    subversion \
    tar \
    unzip \
    vim \
    wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ── Generate and select locale for Perl
RUN echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen && locale-gen en_GB.UTF-8
ENV LANG=en_GB.UTF-8
ENV LANGUAGE=en_GB:en
ENV LC_ALL=en_GB.UTF-8

# ── Directory layout ─────────────────────────────────────────────────
RUN mkdir -p /Rfam/software/bin \
             /Rfam/rfamseq \
             /Rfam/config \
             /workdir \
             /opt/pixi/bin \
             /opt/pixi/cache

ENV USR_BIN=/Rfam/software/bin
ENV DISPLAY=0.0

# ── Pixi installation & Exact Version Tools ───────────────────────────
COPY --from=pixi-provider /usr/local/bin/pixi /usr/local/bin/pixi

ENV PIXI_HOME=/opt/pixi
ENV PIXI_CACHE_DIR=/opt/pixi/cache
ENV PATH=/opt/pixi/bin:$PATH

RUN --mount=type=cache,target=/opt/pixi/cache,sharing=locked \
    pixi global install \
    --channel conda-forge \
    --channel bioconda \
    clustalo==1.2.4 \
    rnacode==0.3 \
    viennarna==2.7.0 \
    t_coffee==11.0.8 \
    hmmer==3.2.1 \
    mafft==7.402 \
    muscle==3.8.31 \
    cmfinder==0.2

RUN --mount=type=cache,target=/opt/pixi/cache,sharing=locked \
    pixi global install \
    --environment infernal \
    --channel conda-forge \
    --channel bioconda \
    infernal==1.1.4 \
    --expose cmbuild \
    --expose cmcalibrate \
    --expose cmalign \
    --expose cmconvert \
    --expose cmemit \
    --expose cmfetch \
    --expose cmpress \
    --expose cmscan \
    --expose cmsearch \
    --expose cmstat

RUN --mount=type=cache,target=/opt/pixi/cache,sharing=locked \
    pixi global install \
    --channel conda-forge \
    --channel bioconda \
    rscape==2.0.4.a \
    --expose R-scape

# Grant execution and read permissions across all users (Singularity compatibility)
RUN chmod -R a+rX /opt/pixi/bin /opt/pixi/envs

RUN cp -s /opt/pixi/bin/R-scape /Rfam/software/bin/R-scape

# ── Compile from source ───────────────────────────────────────────────

# ERATE 0.8
RUN cd /Rfam/software && \
    curl -OL http://eddylab.org/software/erate/erate-v.0.8.tar.gz && \
    tar -xzf erate-v.0.8.tar.gz && rm erate-v.0.8.tar.gz && \
    cd erate-v.0.8/phylip3.66-erate/src && \
    make dnaml && \
    cp dnaml /Rfam/software/bin/

# PPfold 3.1.1
RUN cd /Rfam/software && \
    curl -OL https://web.archive.org/web/20180721090259/http://www.daimi.au.dk/~compbio/pfold/PPfold/PPfold3.1.1.jar && \
    cp PPfold3.1.1.jar /Rfam/software/bin/. && rm PPfold3.1.1.jar

# RAxML
RUN cd /Rfam/software && \
    git init standard-RAxML && \
    cd standard-RAxML && \
    git remote add origin https://github.com/stamatak/standard-RAxML.git && \
    git fetch --depth 1 origin 69a7edcba961f95f732e07ce64e7e5b1c7ae548b && \
    git checkout --detach FETCH_HEAD && \
    rm -rf .git && \
    cd /Rfam/software/standard-RAxML && \
    make -f Makefile.gcc && \
    cp /Rfam/software/standard-RAxML/raxmlHPC /Rfam/software/bin/.

# ── Bio-Easel ─────────────────────────────────────────────────────────
RUN cd /Rfam && \
    git init Bio-Easel && \
    cd Bio-Easel && \
    git remote add origin https://github.com/nawrockie/Bio-Easel.git && \
    git fetch --depth 1 origin ec77fa923b501768346b8870667e7c674a50b009 && \
    git checkout --detach FETCH_HEAD && \
    rm -rf .git && \
    mkdir src && cd src && \
    git init easel && \
    cd easel && \
    git remote add origin https://github.com/EddyRivasLab/easel.git && \
    git fetch --depth 1 origin 3b8fae1aafd36c544108f755a871fcb0d2e7c749 && \
    git checkout --detach FETCH_HEAD && \
    rm -rf .git && \
    sed -i 's/ax_cv_gcc_archflag="unknown"/ax_cv_gcc_archflag="unknown"; :/' aclocal.m4 && \
    autoconf && \
    sed -i -E '/^[[:space:]]*(then|else)[[:space:]]*$/ { n; /^[[:space:]]*fi[[:space:]]*$/ { s/^[[:space:]]*/  :; / } }' configure && \
    sed -i 's/^[[:space:]]*fi[[:space:]]*$/:; fi/g' configure && \
    ./configure --prefix=/usr/local --enable-pic --enable-sse && \
    make && \
    make install && \
    cd /Rfam/Bio-Easel && \
    perl Makefile.PL && \
    make && \
    make install

# ── Clone Rfam pipeline repo ─────────────────────────────────────────
RUN cd /Rfam && git clone --depth 1 https://github.com/Rfam/rfam-family-pipeline.git

# ── Missing Perl module ───────────────────────────────────────────────
RUN cpanm --notest MooseX::Role::Pluggable

# Provide a fallback default rfam.conf so scripts can initialize when run standalone
RUN if [ -f /Rfam/rfam-family-pipeline/Rfam/Conf/rfam.conf ]; then \
        ln -sf /Rfam/rfam-family-pipeline/Rfam/Conf/rfam.conf /Rfam/config/rfam.conf; \
    fi

# Copy CI test configuration into the image
COPY Rfam/Tests/rfam_test.conf        /Rfam/config/rfam_test.conf

# ── Fallback for any missing Perl modules ──────────────────────────────
RUN cpanm --notest Catalyst::Utils 2>/dev/null || true

# Ensure all software directories have universal execution rights
RUN chmod -R a+rwx /Rfam /workdir

# ── Environment setup ─────────────────────────────────────────────────
ENV PATH=/ebi/slurm/codon/bin:/opt/pixi/bin:/usr/bin:$PATH:/Rfam/software/bin:/Rfam/rfam-family-pipeline/Rfam/Scripts/make:/Rfam/rfam-family-pipeline/Rfam/Scripts/qc:/Rfam/rfam-family-pipeline/Rfam/Scripts/jiffies:/Rfam/rfam-family-pipeline/Rfam/Scripts/curation:/Rfam/rfam-family-pipeline/Rfam/Scripts/view:/Rfam/rfam-family-pipeline/Rfam/Scripts/svn:/Rfam/Bio-Easel/scripts

ENV RFAM_CONFIG=/Rfam/config/rfam.conf

ENV PERL5LIB=/Rfam/Bio-Easel/blib/lib:/Rfam/Bio-Easel/blib/arch:/usr/share/perl5:/Rfam/rfam-family-pipeline/Rfam/Lib:/Rfam/rfam-family-pipeline/Rfam/Schemata:/Rfam/rfam-family-pipeline/PfamLib:/Rfam/rfam-family-pipeline/PfamSchemata

# ── Non-root runtime user ────────────────────────────────────────────
RUN useradd --create-home -s /bin/bash rfam-user
USER rfam-user
