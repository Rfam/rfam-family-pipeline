FROM openjdk:8-jdk

USER root

# might need to install a particular version of perl
RUN apt-get update && apt-get install -y curl \
    gcc \
    git \
    tar \
    unzip \
    perl \
    wget \
    make \
    automake \
    curl \
    gzip \
    g++ \
    vim \
    gfortran \
    default-jdk \
    r-base \
    r-base-dev

RUN apt-get install -y libimage-size-perl \
  libtest-most-perl \
  libdbd-mysql-perl \
  libdata-uuid-perl \
  libconvert-color-perl \
  libio-all-perl \
  libdata-pageset-perl \
  libsearch-queryparser-perl \
  libcatalyst-action-renderview-perl \
  libx11-6 \
  && apt-get clean

# create an Rfam directory where all software will be installed
RUN mkdir /Rfam
RUN mkdir /Rfam/software
RUN mkdir /Rfam/software/bin
RUN mkdir /Rfam/rfamseq
RUN mkdir /workdir

# fetch sequence files
RUN cd /Rfam/rfamseq && \
wget ftp://ftp.ebi.ac.uk/pub/databases/Rfam/misc/rfamseq14_test.tar.gz && \
gunzip rfamseq14_test.tar.gz && \
tar -xvf rfamseq14_test.tar

RUN cpan -f install File::ShareDir::Install && \
cpan -f install Inline::C && \
cpan -f install Data::Printer && \
cpan -f install Config::General && \
cpan -f install DBIx::Class::Schema && \
cpan -f install DateTime && \
cpan -f install DateTime::Format::MySQL && \
cpan -f install MooseX::NonMoose && \
cpan -f install Bio::Annotation::Reference && \
cpan -f install File::Touch && \
cpan -f install IPC::Run && \
cpan -f install Term::ReadPassword

ENV PERL5LIB=/usr/share/perl5:/usr/local/share/perl/5.24.1:/usr/bin/perl/:/usr/bin/perl5
ENV USR_BIN=/Rfam/software/bin
ENV DISPLAY=0.0

# SOFTWARE INSTALLATION
# Infernal installation
RUN cd /Rfam/software && \
curl -OL http://eddylab.org/infernal/infernal-1.1.2.tar.gz && \
tar -xvzf infernal-1.1.2.tar.gz && \
cd infernal-1.1.2 && \
./configure && \
make && \
make install && \
cd /Rfam/software/infernal-1.1.2/easel && \
make install && \
cd miniapps && \

# create links to make easel tools available in software bin
cp esl-afetch esl-alimanip esl-alimap esl-alimask esl-alimerge esl-alipid /Rfam/software/bin/. && \
cp esl-alirev esl-cluster esl-alistat esl-compalign esl-compstruct esl-construct /Rfam/software/bin/. && \
cp esl-histplot esl-mask esl-reformat esl-selectn esl-seqrange esl-seqstat /Rfam/software/bin/. && \
cp esl-sfetch esl-shuffle esl-ssdraw esl-translate esl-weight /Rfam/software/bin/.

# make infernal tools available in software bin
RUN cd /Rfam/software/infernal-1.1.2/src && \
cp cmalign cmbuild cmscan cmemit cmpress cmstat cmsearch cmcalibrate /Rfam/software/bin/.

# CMfinder installation
RUN cd /Rfam/software && \
wget http://bio.cs.washington.edu/yzizhen/CMfinder/CMfinder_0.2.tgz && \
tar -xvf CMfinder_0.2.tgz && \
cd CMfinder_0.2 && \
make && \
cp bin/cmfinder /Rfam/software/bin/.

# HMMER installation
RUN cd /Rfam/software && \
wget http://eddylab.org/software/hmmer/hmmer-3.2.1.tar.gz && \
tar -xzf hmmer-3.2.1.tar.gz && \
cd /Rfam/software/hmmer-3.2.1 && \
./configure && \
make && \
make install && \
cd /Rfam/software/hmmer-3.2.1/src && \
cp alimask hmmalign hmmbuild hmmc2 hmmconvert hmmemit hmmerfm-exactmatch /Rfam/software/bin/. && \
cp hmmfetch hmmlogo hmmpgmd hmmpress hmmscan hmmsearch hmmsim hmmstat /Rfam/software/bin/. && \
cp jackhmmer makehmmerdb nhmmer nhmmscan phmmer /Rfam/software/bin/.

# MAFFT installation
RUN cd /Rfam/software && \
curl -OL https://mafft.cbrc.jp/alignment/software/mafft-7.402-with-extensions-src.tgz && \
tar -xzf mafft-7.402-with-extensions-src.tgz && \
cd mafft-7.402-with-extensions/core && \
make clean && \
make && \
make install && \
cd /Rfam/software/mafft-7.402-with-extensions/binaries && \
cp mafft.1 /Rfam/software/bin/mafft

# ERATE installation
RUN cd /Rfam/software && \
curl -OL http://eddylab.org/software/erate/erate-v.0.8.tar.gz && \
tar -xzf erate-v.0.8.tar.gz && \
cd erate-v.0.8/phylip3.66-erate/src && \
make dnaml && \
cp dnaml /Rfam/software/bin/.

# RNAcode installation
RUN cd /Rfam/software && \
curl -OL http://github.com/downloads/wash/rnacode/RNAcode-0.3.tar.gz && \
tar -xzf RNAcode-0.3.tar.gz && \
cd RNAcode-0.3 && \
./configure --prefix=/Rfam/software/RNAcode-0.3 && \
make && \
make install && \
cp /Rfam/software/RNAcode-0.3/bin/RNAcode /Rfam/software/bin/.

# MUSCLE installation
RUN cd /Rfam/software && \
curl -OL http://www.drive5.com/muscle/downloads3.8.31/muscle3.8.31_i86linux64.tar.gz && \
tar -zxvf muscle3.8.31_i86linux64.tar.gz && \
cp /Rfam/software/muscle3.8.31_i86linux64 /Rfam/software/bin/muscle

# argtable2/ClustalW dependencies
RUN cd /Rfam/software && \
curl -OL http://prdownloads.sourceforge.net/argtable/argtable2-13.tar.gz && \
tar -zxvf argtable2-13.tar.gz && \
cd argtable2-13 && \
./configure --prefix=/Rfam/software/argtable2-13 && \
make && \
make install

# ClustalW installation
RUN cd /Rfam/software && \
curl -OL http://www.clustal.org/omega/clustal-omega-1.2.4.tar.gz && \
tar -zxvf clustal-omega-1.2.4.tar.gz && \
cd clustal-omega-1.2.4 && \
./configure CFLAGS=-I/Rfam/software/argtable2-13/include LDFLAGS=-L/Rfam/software/argtable2-13/lib --prefix=/Rfam/software/clustal-omega-1.2.4 && \
make && \
make install && \
cp /Rfam/software/clustal-omega-1.2.4/bin/clustalo /Rfam/software/bin/.

# PPFold installation
RUN cd /Rfam/software && \
curl -OL http://www.daimi.au.dk/~compbio/pfold/PPfold/PPfold3.1.1.jar && \
cp PPfold3.1.1.jar /Rfam/software/bin/.

# RAxML installation
RUN cd /Rfam/software && \
git clone https://github.com/stamatak/standard-RAxML.git && \
cd /Rfam/software/standard-RAxML && \
make -f Makefile.gcc && \
cp /Rfam/software/standard-RAxML/raxmlHPC /Rfam/software/bin/.

# Blast installation
RUN cd /Rfam/software && \
curl -OL ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.7.1+-x64-linux.tar.gz && \
tar -zxvf ncbi-blast-2.7.1+-x64-linux.tar.gz && \
cd /Rfam/software/ncbi-blast-2.7.1+/bin
#cp /Rfam/software/ncbi-blast-2.7.1+/bin/. /Rfam/software/bin/.§1

# ViennaRNA installation
RUN cd /Rfam/software && \
curl -OL https://www.tbi.univie.ac.at/RNA/download/sourcecode/2_4_x/ViennaRNA-2.4.9.tar.gz && \
tar -zxvf ViennaRNA-2.4.9.tar.gz && \
cd ViennaRNA-2.4.9 && \
./configure --prefix=/Rfam/software/ViennaRNA-2.4.9 && \
make && \
make install && \
cd bin && \
cp RNA2Dfold RNALalifold RNALfold RNAPKplex RNAaliduplex RNAalifold /Rfam/software/bin/. && \
cp RNAcofold RNAdistance RNAduplex RNAeval RNAfold RNAforester RNAheat /Rfam/software/bin/. && \
cp RNAinverse RNAlocmin RNApaln RNAparconv RNApdist RNAplex RNAplfold /Rfam/software/bin/. && \
cp RNAplot RNApvmin RNAsnoop RNAsubopt RNAup /Rfam/software/bin/.

#TCOFFEE installation -- test and fix
RUN cd /Rfam/software && \
git clone https://github.com/cbcrg/tcoffee.git tcoffee && \
cd tcoffee/compile && \
make t_coffee

# install Bio-Easel
RUN cd /Rfam && \
git clone https://github.com/nawrockie/Bio-Easel.git && \
cd Bio-Easel && \
mkdir src && cd src && \
git clone https://github.com/EddyRivasLab/easel.git easel && \
cd easel && git checkout tags/Bio-Easel-0.06 && rm -rf .git && \
cd /Rfam/Bio-Easel && perl Makefile.PL && \
make && \
make install

# clone Rfam repo
RUN cd /Rfam && git clone -b rfam-cloud https://github.com/Rfam/rfam-family-pipeline.git && \
cp /Rfam/rfam-family-pipeline/dependencies/plot_outlist.R /Rfam/software/bin/.

# set up user account to prevent from using root to run the scripts
RUN useradd --create-home -s /bin/bash centos
WORKDIR /home/centos
USER centos

# Environment setup
ENV PATH=/usr/bin:$PATH:/Rfam/software/bin:/Rfam/rscape_v0.3.3/bin/:/Rfam/rfam-family-pipeline/Rfam/Scripts/make:/Rfam/rfam-family-pipeline/Rfam/Scripts/qc:/Rfam/rfam-family-pipeline/Rfam/Scripts/jiffies:/Rfam/rfam-family-pipeline/Rfam/Scripts/curation:/Rfam/rfam-family-pipeline/Rfam/Scripts/view:/Rfam/rfam_production/rfam-family-pipeline/Rfam/Scripts/svn:/Rfam/Bio-Easel/scripts

ENV RFAM_CONFIG=/Rfam/rfam-family-pipeline/Rfam/Conf/rfam.conf

ENV PERL5LIB=/usr/bin/perl:/usr/bin/perl5:/Rfam/Bio-Easel/blib/lib:/Rfam/Bio-Easel/blib/arch:/usr/share/perl5:/usr/local/share/perl/5.24.1:/usr/bin/perl/:/usr/share/perl:/usr/share/perl5:/Rfam/rfam-family-pipeline/Rfam/Lib:/Rfam/rfam-family-pipeline/Rfam/Schemata:$PERL5LIB

ENV PERL5LIB=$PERL5LIB:/Rfam/rfam-family-pipeline/PfamLib:/usr/share/perl:/usr/share/perl5
ENV PERL5LIB=$PERL5LIB:/Rfam/rfam-family-pipeline/PfamSchemata
