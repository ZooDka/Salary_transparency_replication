#!/usr/bin/env python3
"""
02_build_sector_panel.py
------------------------
Builds the sectoral employment panel used for Figure A.3
("JoinedDF_age<date>_emp.csv" in the notebook, cells 5-8 and 43-65).

Inputs  (../Data/)
    combined_data.csv      BLS QCEW quarterly files (2020Q1-2024Q2), all areas,
                           stacked; only Area Type == "State" used.
    population.csv         FRED annual state population (thousands), 2020-2024.
    (data/processed/JoinedDF_age.csv from script 01)

Outputs (data/processed/)
    JoinedDF_age_emp.csv       weekly x state x ownership x industry (notebook output)
    sector_monthly_panel.csv   collapsed to state x month x ownership x industry,
                               which is what att_gt() needs (one row per id-period)
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT.parent / "Data"
OUT = ROOT / "data" / "processed"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from importlib import import_module
STATE2ABBREV = import_module("01_build_weekly_panel").STATE2ABBREV  # noqa: E402

MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july',
          'august', 'september', 'october', 'november', 'december']
MONTH_NUM = {m.capitalize(): f"{i:02d}" for i, m in enumerate(MONTHS, 1)}


def qcew_long():
    """Notebook cells 5-8: state-level QCEW, wide monthly columns -> long."""
    df = pd.read_csv(RAW / "combined_data.csv", low_memory=False)
    df = df[df['Area Type'] == 'State']
    df = df.drop(columns=['Area', 'Area\nCode', 'Own', 'St', 'Area Type', 'Cnty', 'NAICS',
                          'Status Code', 'Establishment Count',
                          'Total Wage Location Quotient Relative to U.S.',
                          'Employment Location Quotient Relative to U.S.'])
    df = df.rename(columns={c: c.replace(" Employment", "") for c in df.columns if " Employment" in c})

    month_cols = [c for c in df.columns if c.lower() in MONTHS]
    long = df.melt(id_vars=['Year', 'Qtr', 'Ownership', 'St Name', 'Industry',
                            'Average Weekly Wage', 'Total Quarterly Wages'],
                   value_vars=month_cols, var_name='Month', value_name='Employment')
    long = long.dropna(subset=['Employment'])          # each quarter file only fills its 3 months
    long['Month'] = long['Month'].str.capitalize().map(MONTH_NUM)
    long['Year'] = long['Year'].astype(int)
    long['Date'] = pd.to_datetime(long['Year'].astype(str) + '-' + long['Month'], format='%Y-%m')
    long = long.drop(columns=['Qtr'])
    return long


def main():
    emp = qcew_long()
    print(f"QCEW long: {len(emp):,} rows; months {emp['Date'].min().date()} -> {emp['Date'].max().date()}")

    # cell 44
    emp = emp.rename(columns={'St Name': 'state'})
    emp['state'] = emp['state'].str.strip().replace(STATE2ABBREV).str.lower()
    emp['month'] = emp['Date'].dt.strftime('%Y-%m')
    emp = emp.drop(columns=['Month', 'Year'])

    # cell 45-46: attach to the weekly Indeed/COVID panel on state-month
    wk = pd.read_csv(OUT / "JoinedDF_age.csv")
    wk['week_ending'] = pd.to_datetime(wk['week_ending'])
    wk['month'] = wk['week_ending'].dt.strftime('%Y-%m')
    wk = wk.drop(columns=['Death Data As Of'])
    merged = pd.merge(wk, emp, on=['state', 'month'], how='left').drop(columns=['Date'])
    print(f"weekly x industry x ownership: {len(merged):,} rows (notebook: 208,979)")

    # cells 48-52: population (thousands) by state-year -> employment rate
    pop = pd.read_csv(RAW / "population.csv")
    pop['observation_date'] = pd.to_datetime(pop['observation_date'], format='mixed')
    pop = pop.melt(id_vars=['observation_date'], var_name='state', value_name='population')
    pop['state'] = pop['state'].str.lower()
    pop['year'] = pop['observation_date'].dt.year
    merged['year'] = pd.to_datetime(merged['month']).dt.year
    merged = pd.merge(merged, pop, on=['year', 'state'], how='left')
    # NOTE: same formula as the notebook. population is in THOUSANDS, so
    # employment_rate = 10 x (employment / population). It is a monotone rescaling
    # and does not change inference; Figure A.3's y-axis is in these units.
    merged['employment_rate'] = (merged['Employment'] / (merged['population'] * 10000)) * 100

    # cells 56-64: monthly / quarterly sums of the (cumulative) death-rate column
    merged = merged.drop(columns=['observation_date', 'year', 'month'])
    merged['year_month'] = merged['week_ending'].dt.strftime('%Y-%m')
    tdm = merged[['Total Deaths Per 100000 (age-adjusted)', 'week_ending', 'state']].copy()
    tdm['year_month'] = tdm['week_ending'].dt.strftime('%Y-%m')
    tdm['Total Deaths Per 100000 (age-adjusted)'] = pd.to_numeric(
        tdm['Total Deaths Per 100000 (age-adjusted)'], errors='coerce')
    tdg = (tdm.groupby(['state', 'year_month'])['Total Deaths Per 100000 (age-adjusted)']
           .sum().reset_index()
           .rename(columns={'Total Deaths Per 100000 (age-adjusted)':
                            'Monthly Total Deaths Per 100000 (age-adjusted)'}))
    merged = pd.merge(merged, tdg, on=['state', 'year_month'], how='left').drop(columns=['year_month'])
    merged['quarter'] = merged['week_ending'].dt.to_period('Q').astype(str)
    qd = (merged.groupby(['state', 'quarter'])['Monthly Total Deaths Per 100000 (age-adjusted)']
          .sum().reset_index()
          .rename(columns={'Monthly Total Deaths Per 100000 (age-adjusted)':
                           'Quarterly Total Deaths Per 100000 (age-adjusted)'}))
    merged = pd.merge(merged, qd, on=['state', 'quarter'], how='left')
    merged.to_csv(OUT / "JoinedDF_age_emp.csv", index=False)
    print(f"JoinedDF_age_emp.csv written: {len(merged):,} rows")

    # ---- collapse to one row per state-month-ownership-industry for att_gt() -----
    # Weekly death rate (first difference of the cumulative CDC series, as in
    # 00_prep.R) summed within month = monthly change in deaths per 100k.
    wk2 = wk.sort_values(['state', 'week_ending']).copy()
    wk2['dweekly_deathRate'] = wk2.groupby('state')['Total Deaths Per 100000 (age-adjusted)'].diff().fillna(0)
    wkm = (wk2.groupby(['state', 'month'])
           .agg(indeed_job_postings_index=('indeed_job_postings_index', 'mean'),
                is_date_passed=('is_date_passed', 'max'),
                dmonthly_deathRate=('dweekly_deathRate', 'sum'),
                cum_deathRate_end=('Total Deaths Per 100000 (age-adjusted)', 'last'),
                n_weeks=('week_ending', 'size'))
           .reset_index())
    sec = pd.merge(wkm, emp, on=['state', 'month'], how='inner')
    pop2 = pop[['state', 'year', 'population']]
    sec['year'] = pd.to_datetime(sec['month']).dt.year
    sec = pd.merge(sec, pop2, on=['state', 'year'], how='left').drop(columns=['year'])
    sec['employment_rate'] = (sec['Employment'] / (sec['population'] * 10000)) * 100
    sec['month_index'] = ((pd.to_datetime(sec['month']).dt.year - 2020) * 12
                          + pd.to_datetime(sec['month']).dt.month - 2)      # 2020-02 -> 0
    first_treat = (sec[sec['is_date_passed'] == 1].groupby('state')['month_index'].min()
                   .rename('first_treat_month'))
    sec = sec.merge(first_treat, on='state', how='left')
    sec['first_treat_month'] = sec['first_treat_month'].fillna(0).astype(int)
    sec = sec.sort_values(['Ownership', 'Industry', 'state', 'month_index'])
    sec.to_csv(OUT / "sector_monthly_panel.csv", index=False)
    print(f"sector_monthly_panel.csv: {len(sec):,} rows; "
          f"{sec['Industry'].nunique()} industries x {sec['Ownership'].nunique()} ownerships; "
          f"months {sec['month'].min()} -> {sec['month'].max()}")
    print("first treated month index by state:",
          sec[sec.first_treat_month > 0].groupby('state')['first_treat_month'].first().to_dict())
    return 0


if __name__ == "__main__":
    sys.exit(main())
