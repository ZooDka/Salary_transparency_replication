#!/usr/bin/env python3
"""
01_build_weekly_panel.py
------------------------
Builds the weekly state panel ("JoinedDF_age081924.csv" in the R scripts).
Same steps as the data-management cells of
`Copy_of_121324EditsResearchZogaIndeed.ipynb` (cells 18, 31-42).

Inputs  (../Data/)
    state_job_postings_us_072924.csv   Indeed state index, daily, as published
                                       in hiring-lab/job_postings_tracker on
                                       2024-07-29 (commit 6664423, "2024-07-19
                                       update"). Indeed has since revised the
                                       index; use this file, not the current one.
    LawPassed_072424.csv               Hand-coded law dates (9 states).
    covid_concatinated_age_adjusted.csv CDC COVID Data Tracker export, weekly
                                       cumulative age-adjusted deaths / 100k.

Output (data/processed/)
    JoinedDF_age.csv   51 states x 234 weeks (11,934 rows)
"""
import io
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT.parent / "Data"
OUT = ROOT / "data" / "processed"
OUT.mkdir(parents=True, exist_ok=True)

STATE2ABBREV = {
    'Alaska': 'AK', 'Alabama': 'AL', 'Arkansas': 'AR', 'Arizona': 'AZ',
    'California': 'CA', 'Colorado': 'CO', 'Connecticut': 'CT',
    'District of Columbia': 'DC', 'Delaware': 'DE', 'Florida': 'FL',
    'Georgia': 'GA', 'Hawaii': 'HI', 'Iowa': 'IA', 'Idaho': 'ID',
    'Illinois': 'IL', 'Indiana': 'IN', 'Kansas': 'KS', 'Kentucky': 'KY',
    'Louisiana': 'LA', 'Massachusetts': 'MA', 'Maryland': 'MD', 'Maine': 'ME',
    'Michigan': 'MI', 'Minnesota': 'MN', 'Missouri': 'MO', 'Mississippi': 'MS',
    'Montana': 'MT', 'North Carolina': 'NC', 'North Dakota': 'ND',
    'Nebraska': 'NE', 'New Hampshire': 'NH', 'New Jersey': 'NJ',
    'New Mexico': 'NM', 'Nevada': 'NV', 'New York': 'NY', 'Ohio': 'OH',
    'Oklahoma': 'OK', 'Oregon': 'OR', 'Pennsylvania': 'PA',
    'Rhode Island': 'RI', 'South Carolina': 'SC', 'South Dakota': 'SD',
    'Tennessee': 'TN', 'Texas': 'TX', 'Utah': 'UT', 'Virginia': 'VA',
    'Vermont': 'VT', 'Washington': 'WA', 'Wisconsin': 'WI',
    'West Virginia': 'WV', 'Wyoming': 'WY', 'Puerto Rico': 'PR',
    'Virigin Islands': 'VI',
}
MONTH_MAP = {m: f"{i:02d}" for i, m in enumerate(
    ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'], 1)}


def build_daily_joined():
    """Notebook cell 18: join law dates onto the daily Indeed index."""
    dfJobs = pd.read_csv(RAW / "state_job_postings_us_072924.csv")
    dfJobs['date'] = pd.to_datetime(dfJobs['date'])

    dfLaws = pd.read_csv(RAW / "LawPassed_072424.csv")
    dfLaws['state'] = dfLaws['state'].str.lower()
    dfLaws['date'] = pd.to_datetime(dfLaws['Date'], format='mixed')

    joinedDF = pd.merge(dfLaws, dfJobs, on='state', how='right')
    joinedDF["from_baseline"] = (joinedDF["date_y"] - joinedDF["date_x"]).dt.days
    joinedDF["is_date_passed"] = np.where(joinedDF["date_y"] >= joinedDF["date_x"], 1, 0)
    joinedDF = joinedDF.rename(columns={"date_x": "date_passed", "date_y": "date"})
    joinedDF = joinedDF.drop(columns="Date")
    return joinedDF


def build_weekly(joinedDF):
    """Notebook cell 35: average the daily index within weeks ending Saturday."""
    weekly = (joinedDF
              .groupby(['state', pd.Grouper(key='date', freq='W-SAT')])
              .agg({'indeed_job_postings_index': 'mean',
                    'is_date_passed': 'max',
                    'from_baseline': 'max'})
              .reset_index()
              .rename(columns={'date': 'week_ending'}))
    weekly['state'] = weekly['state'].astype(str)
    return weekly


def read_cdc(fname, rate_col):
    """Notebook cells 31-34: clean a CDC Data Tracker multi-state export."""
    with open(RAW / fname, 'r', encoding='utf-8-sig') as fh:
        lines = [l for l in fh
                 if "Data Table for Weekly" not in l and "Date generated" not in l]
    c = pd.read_csv(io.StringIO("".join(lines)))
    c = c.drop_duplicates(subset=['Geography', 'Date', 'Weekly Deaths', rate_col,
                                  'Death Data As Of'], keep='first')

    # suppressed small counts, exactly as in the notebook
    c['Weekly Deaths'] = c['Weekly Deaths'].replace(['Counts 1-9'], 5)
    c['Weekly Deaths'] = c['Weekly Deaths'].replace(['Counts <20'], 10)
    c[rate_col] = c[rate_col].replace(['Counts 1-9'], 0)
    c[rate_col] = c[rate_col].replace(['Counts <20'], 0)

    # "Aug  3 2024" -> 2024-08-03
    c['day'] = c['Date'].str.extract(r'(\d{1,2})')
    c['month'] = c['Date'].str.extract(r'([A-Za-z]{3})')[0].map(MONTH_MAP)
    c['year'] = c['Date'].str.extract(r'(\d{4})')
    c['week_ending'] = pd.to_datetime(c['year'] + '-' + c['month'] + '-' + c['day'])
    c = c.drop(columns=['day', 'month', 'year', 'Date'])
    c = c.rename(columns={'Geography': 'state', 'Weekly Deaths': 'weekly_deaths'})
    c['state'] = c['state'].str.strip().replace(STATE2ABBREV).str.lower()
    c['state'] = c['state'].astype(str)
    return c


def main():
    joinedDF = build_daily_joined()
    joinedDF.to_csv(OUT / "joinedDF_daily.csv", index=False)
    print(f"daily joined: {len(joinedDF):,} rows "
          f"({joinedDF['date'].min().date()} -> {joinedDF['date'].max().date()})")

    weekly = build_weekly(joinedDF)
    print(f"weekly: {len(weekly):,} rows; weeks per state = "
          f"{weekly.groupby('state').size().unique().tolist()}")

    cdc_age = read_cdc("covid_concatinated_age_adjusted.csv",
                       'Total Deaths Per 100000 (age-adjusted)')
    joined_age = pd.merge(weekly, cdc_age, on=['state', 'week_ending'], how='left')
    joined_age.to_csv(OUT / "JoinedDF_age.csv", index=False)
    print(f"JoinedDF_age.csv: {len(joined_age):,} rows, "
          f"{joined_age['Total Deaths Per 100000 (age-adjusted)'].isna().sum()} "
          f"missing COVID cells")

    # crude version (built by the notebook; not used in the paper, kept for completeness)
    cdc_crude = read_cdc("covid_concatinated_crude.csv", 'Total Deaths Per 100000 (crude)')
    cdc_crude = cdc_crude.rename(
        columns={'Total Deaths Per 100000 (crude)': 'total_deaths_per_100k_crude'})
    joined_crude = pd.merge(weekly, cdc_crude, on=['state', 'week_ending'], how='left')
    joined_crude.to_csv(OUT / "JoinedDF_crude.csv", index=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
