sudo apt-get install rpm
sudo apt-get install pigz
sudo apt-get install wget
wget https://repo.anaconda.com/miniconda/Miniconda3-py39_4.12.0-Linux-x86_64.sh
bash Miniconda3-py39_4.12.0-Linux-x86_64.sh
source .bashrc
echo 'installing conda'

#install bcl2fastq
conda install -c dranew bcl2fastq
#chmod +x bcl2fastq.sh
echo 'installing bcl2fastq'

#install fastqc
sudo apt-get -y install fastqc
echo 'installing fastqc'

#install umitools
sudo apt-get -y install gcc
conda install bioconda::umi_tools=1.0.1
echo 'installing umi_tools'

#install rsem for host alignment
conda install -c bioconda rsem

# install nextflow
export OS=linux ARCH=amd64
export NXF_VER=21.10.0
export NXF_MODE=google
curl https://get.nextflow.io | bash

#install git
conda install git

# install Singularity requirements
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    pkg-config

# install GO
export VERSION=1.19.3 && \
    wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz && \
    sudo tar -C /usr/local -xzvf go$VERSION.$OS-$ARCH.tar.gz && \
    rm go$VERSION.$OS-$ARCH.tar.gz
# set up environment variables
echo 'export GOPATH=${HOME}/go' >> ~/.bashrc
echo 'export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin' >> ~/.bashrc
source ~/.bashrc
curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | \
    sh -s -- -b $(go env GOPATH)/bin v1.21.0
git clone --recursive https://github.com/sylabs/singularity.git
singularity version
cd singularity
sudo apt-get install glib2-devel
sudo apt-get install libgtk2.0-dev
./mconfig
sudo make -C builddir install

nextflow pull cgunnars/dualrnaseq_umi
sudo singularity build .nextflow/assets/cgunnars/dualrnaseq_umi/nfcore-dualrnaseq-umi-1.0.0.img .nextflow/assets/cgunnars/dualrnaseq_umi/nfcore-dualrnaseq-umi-1.0.0.def

./nextflow run cgunnars/dualrnaseq_umi -profile test,singularity
