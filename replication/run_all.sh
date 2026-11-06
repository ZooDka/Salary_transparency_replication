#!/usr/bin/env bash
# Runs every script in code/ in order.
# Run from this folder:  bash run_all.sh
# Total run time ~10 minutes (four att_gt() calls with 1000 bootstrap draws each
# for Figs 2/A.4/A.5/A.6, plus 11 sector models for Fig A.3).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p data/processed output/figures output/tables
[ -f ../Data/combined_data.csv ] || { echo "[0/7] combined_data.csv from the QCEW workbooks"; python3 code/00a_build_combined_data.py ../Data/RR ../Data/combined_data.csv; }

echo "[1/7] weekly panel (Indeed x laws x CDC)";             python3 code/01_build_weekly_panel.py
echo "[2/7] sector panel (QCEW x population)";              python3 code/02_build_sector_panel.py
echo "[3/7] Section 3 numbers, Tables A.1 & A.2";           Rscript code/03_summary_stats.R
echo "[4/7] Table A.3 (TWFE)";                              Rscript code/04_twfe.R
echo "[5/7] CSDID: Fig 2, Section 4 numbers, Figs A.4-A.6"; Rscript code/05_csdid_main.R
echo "[6/7] Figure 1";                                      Rscript code/06_figure1.R
echo "[7/7] Figure A.3 (sector event studies)";             Rscript code/07_sector_csdid.R
echo "Done. See output/tables and output/figures."
