#!/usr/bin/env python3
"""Build combined_data.csv from the BLS QCEW quarterly 'all high-level county' workbooks
(Data/RR/<year>_all_county_high_level/allhlcnYYQ.xlsx). The annual workbooks (allhlcnYY.xlsx)
are not used. Rows are the workbooks stacked in the order listed in the script;
the order does not matter for anything downstream."""
import sys, glob, os, pandas as pd
rr = sys.argv[1] if len(sys.argv) > 1 else "../Data/RR"
out = sys.argv[2] if len(sys.argv) > 2 else "../Data/combined_data.csv"
order = [(2022,1),(2023,3),(2021,4),(2022,2),(2023,4),(2024,1),(2024,2),(2023,1),(2021,2),(2020,1),
         (2020,2),(2021,1),(2022,4),(2020,4),(2021,3),(2023,2),(2020,3),(2022,3)]
parts = [pd.read_excel(f"{rr}/{y}_all_county_high_level/allhlcn{str(y)[2:]}{q}.xlsx") for y, q in order]
df = pd.concat(parts, ignore_index=True)
cols = ['Area\nCode','St','Cnty','Own','NAICS','Year','Qtr','Area Type','St Name','Area','Ownership','Industry','Status Code',
        'Establishment Count','January Employment','February Employment','March Employment','Total Quarterly Wages','Average Weekly Wage',
        'Employment Location Quotient Relative to U.S.','Total Wage Location Quotient Relative to U.S.','July Employment','August Employment',
        'September Employment','October Employment','November Employment','December Employment','April Employment','May Employment','June Employment']
df[cols].to_csv(out, index=False)
print(f"{out}: {len(df):,} rows")
