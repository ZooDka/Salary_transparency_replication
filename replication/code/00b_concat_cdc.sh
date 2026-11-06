#!/usr/bin/env bash
# Build covid_concatinated_age_adjusted.csv and covid_concatinated_crude.csv: a plain concatenation
# (headers included, alphabetical by state file name) of the CDC COVID Data Tracker per-state exports
# in ../Data/covid_raw_files/. The notebook strips the per-file header lines when it reads them.
set -e
raw="${1:-../Data/covid_raw_files}"
ls "$raw"/age_adjusted/data_table_*.csv | sort | xargs cat > covid_concatinated_age_adjusted.csv
ls "$raw"/crude/data_table_*.csv        | sort | xargs cat > covid_concatinated_crude.csv
