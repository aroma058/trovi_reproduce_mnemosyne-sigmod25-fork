#!/bin/bash
# Reproduces Figure 4 of Mnemosyne (SIGMOD '25):
# Output: exp-figures/Fig4.png
set -e

# ---------- 1. Install dependencies ----------
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential pkg-config \
    libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev \
    python3-matplotlib python3-pandas python3-numpy \
    texlive-latex-extra texlive-fonts-recommended cm-super dvipng

# ---------- 2. Download the code that lives in other repos (submodules) ----------
# The submodule links use git@github.com:, which needs SSH keys. Use https instead.
git config --global url."https://github.com/".insteadOf git@github.com:
git submodule init
git submodule update K-V-Workload-Generator skew-aware-rocksdb-8.9.1 skew-aware-bpk-benchmark

# ---------- 3. Compile ----------
cd K-V-Workload-Generator
make load_gen
cd ..

cd skew-aware-rocksdb-8.9.1
make static_lib -j$(nproc)
cd ..

cd skew-aware-bpk-benchmark
make bpk_benchmark
cd ..

# ---------- 4. Set up a RAM disk for the database ----------
sudo mkdir -p /mnt/ramdisk
if ! mountpoint -q /mnt/ramdisk; then
    sudo mount -t tmpfs -o size=80G tmpfs /mnt/ramdisk
fi
sudo chown -R $(whoami) /mnt/ramdisk
mkdir -p /mnt/ramdisk/db_working_home
export RAM_DB_HOME=/mnt/ramdisk/db_working_home

# ---------- 5. Run the Figure 4 experiment ----------
ulimit -n 65536
rm -f exp-figures/Fig4.png   # remove the authors' copy so we only see our own result
cd exp-scripts
./fig4.sh
cd ..

echo "Done. Figure saved at exp-figures/Fig4.png"
