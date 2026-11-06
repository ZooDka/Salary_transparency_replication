# Duka & Weber (2025), "The effect of mandatory salary revelations on job postings", Economics Letters 254, 112423

## How to run

1. Python: `pip install -r requirements.txt`. From this folder run `python3 replication/code/01_build_weekly_panel.py`. It builds the weekly panel from the files in `Data/` and writes `replication/data/processed/JoinedDF_age.csv`, which is the same as `JoinedDF_age081924.csv` in this folder.
   The original notebook `Copy_of_121324EditsResearchZogaIndeed.ipynb` does the same steps. To run it, first build `Data/combined_data.csv` (too big for GitHub) from the QCEW workbooks: `python3 replication/code/00a_build_combined_data.py Data/RR Data/combined_data.csv`. The notebook reads its input files from its own folder, so copy it into `Data/` and run it there (or on Colab with the `Data/` files uploaded next to it). It writes `JoinedDF_age<date>.csv`.
2. R: install the packages in `R_packages.txt`. From this folder run `RCode.R` (Section 3, Figure 2, Section 4 numbers) and `TransparencyAndIndeed2024_09_12.R` (same plus Figure 1 and Table A.1).
3. `TableA2_A3.R` (run from this folder) prints Table A.2 and Table A.3.
4. `replication/`: `bash setup_environment.sh` then `bash run_all.sh` for Figures A.3 to A.6. Results go to `replication/output/`.

## Files

| file | what it is |
|---|---|
| `Copy_of_121324EditsResearchZogaIndeed.ipynb` | builds the weekly panel from the raw data in `Data/` |
| `RCode.R` | summary statistics, event studies, Callaway-Sant'Anna estimation (Figure 2, Section 4) |
| `TransparencyAndIndeed2024_09_12.R` | same as `RCode.R` plus Figure 1 and Table A.1 |
| `TableA2_A3.R` | prints Table A.2 and Table A.3 |
| `JoinedDF_age081924.csv` | weekly panel (51 states x 234 weeks) read by the R scripts |
| `IndeedDataSummary.xlsx` | Table A.1 |
| `requirements.txt`, `R_packages.txt` | Python and R packages |
| `Data/state_job_postings_us_072924.csv` | Indeed state job postings index, daily (github.com/hiring-lab/job_postings_tracker, `US/state_job_postings_us.csv`, commit 6664423, downloaded 2024-07-29; the current file on GitHub is revised, use this one) |
| `Data/LawPassed_072424.csv` | law dates for the nine treated states |
| `Data/covid_concatinated_age_adjusted.csv`, `Data/covid_concatinated_crude.csv` | weekly cumulative COVID deaths per 100k by state (CDC COVID Data Tracker, 2024-08-15); raw per-state files in `Data/covid_raw_files/` |
| `Data/RR/` | BLS QCEW quarterly employment workbooks 2020Q1 to 2024Q2; `00a_build_combined_data.py` stacks them into `Data/combined_data.csv` |
| `Data/population.csv` | annual state population (FRED) |
| `Data/fredgraph-*.csv` | monthly state unemployment rates (FRED), read by the notebook, not used in the paper |
| `replication/` | code for every table and figure, files listed below |

## Files in replication

| file | what it is |
|---|---|
| `replication/run_all.sh` | runs everything |
| `replication/setup_environment.sh` | installs Python and R packages (did 2.1.2) |
| `replication/code/00_prep.R` | data preparation shared by the R scripts |
| `replication/code/00a_build_combined_data.py` | stacks the QCEW workbooks in `Data/RR/` into `Data/combined_data.csv` (run_all.sh does this if the file is missing) |
| `replication/code/00b_concat_cdc.sh` | concatenates the CDC per-state files in `../Data/covid_raw_files/` into `covid_concatinated_*.csv` |
| `replication/code/01_build_weekly_panel.py` | builds the weekly panel from the files in `Data/` |
| `replication/code/02_build_sector_panel.py` | builds the sector employment panel for Figure A.3 from the files in `Data/` |
| `replication/code/03_summary_stats.R` | Section 3 numbers, Table A.1, Table A.2 |
| `replication/code/04_twfe.R` | Table A.3 |
| `replication/code/05_csdid_main.R` | Figure 2, Section 4 numbers, Figures A.4, A.5, A.6 |
| `replication/code/06_figure1.R` | Figure 1 |
| `replication/code/07_sector_csdid.R` | Figure A.3 |
| `replication/data/processed/` | panels built by the scripts (created when run) |
| `replication/output/figures/` | Figure1, Figure2, FigureA3 (one file per sector plus the combined panel), FigureA4, FigureA5, FigureA6 |
| `replication/output/tables/` | TableA1, TableA2, TableA3, Figure 2 ATT by week, placebo assignments for A.5 and A.6 |

## Data sources

| data | source |
|---|---|
| `Data/state_job_postings_us_072924.csv` | Indeed Hiring Lab, Job Postings Tracker, https://github.com/hiring-lab/job_postings_tracker. Licensed under the Creative Commons Attribution 4.0 International License (https://creativecommons.org/licenses/by/4.0/). |
| `Data/covid_concatinated_*.csv`, `Data/covid_raw_files/` | Centers for Disease Control and Prevention, COVID Data Tracker, https://covid.cdc.gov/covid-data-tracker/#trends_weeklydeaths_totaldeathrateaa_01 |
| `Data/RR/` | U.S. Bureau of Labor Statistics, Quarterly Census of Employment and Wages, https://www.bls.gov/cew/downloadable-data-files.htm |
| `Data/population.csv`, `Data/fredgraph-*.csv` | FRED, Federal Reserve Bank of St. Louis, https://fred.stlouisfed.org |
| `Data/LawPassed_072424.csv` | hand-coded by the authors from Westlaw |

## License

The code is under the MIT License (see `LICENSE`). The data in `Data/` from Indeed Hiring Lab, BLS, CDC and FRED stays under the terms of its original source.
