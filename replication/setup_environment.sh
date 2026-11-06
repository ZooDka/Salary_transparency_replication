#!/usr/bin/env bash
# One-time environment setup. Tested on Ubuntu 24.04 with R 4.3.3.
#
# Python:  pandas >= 2.0, numpy, openpyxl
# R:       dplyr tidyr ggplot2 ggpubr data.table Matrix pbapply sandwich lmtest broom
#          + did 2.1.2 / DRDID 1.0.6 / BMisc 1.4.6 / trust
set -euo pipefail

pip install "pandas>=2.0" numpy openpyxl

# --- R packages from CRAN -----------------------------------
Rscript -e '
  pk <- c("dplyr","tidyr","ggplot2","ggpubr","data.table","Matrix","pbapply","sandwich","lmtest","broom","remotes")
  pk <- pk[!pk %in% rownames(installed.packages())]
  if (length(pk)) install.packages(pk, repos = "https://cloud.r-project.org")
  # pinned versions:
  remotes::install_version("BMisc", "1.4.6", repos = "https://cloud.r-project.org")
  remotes::install_version("DRDID", "1.0.6", repos = "https://cloud.r-project.org")
  remotes::install_version("did",   "2.1.2", repos = "https://cloud.r-project.org")'

# --- Fallback if CRAN is unreachable: Ubuntu r-cran-* packages + GitHub CRAN mirror.
#   sudo apt-get install -y r-base-core r-cran-ggplot2 r-cran-data.table r-cran-dplyr r-cran-tidyr \
#        r-cran-plm r-cran-sandwich r-cran-lmtest r-cran-remotes r-cran-pbapply r-cran-tidyselect \
#        r-cran-xtable r-cran-matrix r-cran-rcpp r-cran-mass r-cran-broom r-cran-ggpubr r-cran-rcpparmadillo
#   for p in BMisc:1.4.6 trust:0.1-8 DRDID:1.0.6 did:2.1.2; do
#     n=${p%%:*}; v=${p##*:}
#     git clone -q --depth 50 https://github.com/cran/$n.git && (cd $n && git checkout -q $v) && R CMD INSTALL --no-docs $n
#   done
