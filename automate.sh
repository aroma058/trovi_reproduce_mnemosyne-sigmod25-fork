#!/bin/bash
# Reproduces Figure 12 of Mnemosyne (SIGMOD '25) at a smaller scale:
# read bytes (a-f) and read latency (g-l) for RocksDB vs Mnemosyne vs Mnemosyne+.
#
# Changes from the paper's setup, so it finishes in about 7-9 hours on a Chameleon node:
#   - 1/8 of the data: 2.625M inserts (paper: 21M)
#   - 1/16 of the operations: 1.9375M queries, 0.625M updates (paper: 31M / 10M), same query:update ratio
#   - 1/8 of the block cache (64 MB instead of 512 MB), so the cache-to-data ratio stays the same
#   - 3 bits-per-key values (2, 4, 6) instead of 6 (2-7)
#   - 1 run per setting (same as the authors' default RUNS=1)
# Output: exp-figures/Fig12.png (ours) and exp-figures/Fig12_original.png (authors')
set -e
echo "Started at: $(date)"

# ---------- 1. Install dependencies ----------
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential pkg-config \
    libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev \
    python3-matplotlib python3-pandas python3-numpy python3-pil poppler-utils \
    texlive-latex-extra texlive-fonts-recommended cm-super dvipng

# ---------- 2. Download the code that lives in other repos (submodules) ----------
# The submodule links use git@github.com:, which needs SSH keys. Use https instead.
git config --global url."https://github.com/".insteadOf git@github.com:
git submodule init
git submodule update K-V-Workload-Generator skew-aware-rocksdb-8.9.1 skew-aware-bpk-benchmark

# Start from clean copies, so running this script twice gives the same result
git checkout -- workload_generator_scripts exp-figures plot_scripts
git -C skew-aware-bpk-benchmark checkout -- .
# Remove results from any earlier run
rm -rf skew-aware-bpk-benchmark/output-bpk* skew-aware-bpk-benchmark/agg_output

# Newer Ubuntu no longer has sys/vtimes.h. The benchmark includes it but never uses it, so remove that line.
sed -i '/sys\/vtimes.h/d' skew-aware-bpk-benchmark/emu_util.cc

# ---------- 3. Make the experiment smaller ----------
# 1/8 of the data, 1/16 of the operations
sed -i 's/^I="21000000"/I="2625000"/; s/^Q="31000000"/Q="1937500"/; s/^U="10000000"/U="625000"/' \
    workload_generator_scripts/workload_type_II.sh
# 3 bits-per-key values and 1/8 of the block cache
sed -i 's/^bpk_list=.*/bpk_list=("2" "4" "6")/; s/^BCC=.*/BCC="65536"/' \
    skew-aware-bpk-benchmark/exp_query_lat.sh
# Tell the result-merging script about the 3 bits-per-key values
sed -i 's/^bpk_list = .*/bpk_list = ["2.0","4.0","6.0"]/' \
    skew-aware-bpk-benchmark/merge_by_short_bpk_with_rw_latency.py

# The authors' plot fixes the y-axis range for their machine and data size.
# Let the y-axis fit our numbers instead (smaller data, different SSD).
sed -i '0,/^    if args.showLegend:/s//    ax.yaxis.set_major_locator(mpl.ticker.AutoLocator()); ax.set_autoscaley_on(True); ax.relim(); ax.autoscale_view(scalex=False); ax.set_ylim(bottom=0)\n    if args.showLegend:/' \
    plot_scripts/mnemosyneplus-main-exp-plot.py

echo "Settings used:"
grep -E '^(I|Q|U)=' workload_generator_scripts/workload_type_II.sh
grep -E '^(bpk_list|BCC)=' skew-aware-bpk-benchmark/exp_query_lat.sh

# Keep a copy of the authors' Figure 12 panels before they get overwritten
mkdir -p exp-figures/original
cp exp-figures/Fig12-*.pdf exp-figures/original/

# ---------- 4. Compile ----------
cd K-V-Workload-Generator
make load_gen
cd ..

cd skew-aware-rocksdb-8.9.1
make static_lib -j$(nproc)
cd ..

cd skew-aware-bpk-benchmark
make query_lat_exp
cd ..

# ---------- 5. Run the Figure 12 experiment ----------
# The database goes on the machine's local disk
export FAST_DB_HOME=$HOME/db_working_home
mkdir -p $FAST_DB_HOME
ulimit -n 65536
cd exp-scripts
./fig12.sh
cd ..

# ---------- 6. Put the 12 panels into one picture ----------
python3 make_fig12_grid.py exp-figures exp-figures/Fig12.png
python3 make_fig12_grid.py exp-figures/original exp-figures/Fig12_original.png

echo "Finished at: $(date)"
echo "Done. Figure saved at exp-figures/Fig12.png"
