## About Jupyter Data Science Notebook

Jupyter Data Science Notebook is a multi-language interactive notebook environment that bundles Python, R, and Julia
together with the JupyterLab and Notebook frontends. It is part of the
[Jupyter Docker Stacks](https://jupyter-docker-stacks.readthedocs.io/) family of community-maintained Jupyter images and
targets data science, statistical computing, and numerical research workflows that need more than one language under the
same kernel host.

The Docker Hardened Image variant ships the same set of conda-forge packages as upstream
`quay.io/jupyter/datascience-notebook`, with all downloaded binaries (micromamba, Julia) pinned to specific versions and
verified by SHA256.

## What's inside

- **JupyterLab** and the classic **Notebook** frontend for interactive computing, plus `jupyterhub-singleuser` for use
  inside JupyterHub.
- **Python 3.13** with the scientific computing stack: pandas, NumPy, SciPy, scikit-learn, scikit-image, statsmodels,
  sympy, matplotlib, seaborn, bokeh, altair, dask, numba, h5py, and more.
- **R** with `r-base`, `tidyverse`, `tidymodels`, `caret`, `forecast`, `randomforest`, `shiny`, `rmarkdown`, `IRkernel`
  (R kernel for Jupyter), and `rpy2` for Python-R interoperability.
- **Julia 1.12** with `IJulia` (Julia kernel for Jupyter), `HDF5`, and `Pluto` for reactive notebooks, plus
  `jupyter-pluto-proxy`.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Jupyter, JupyterLab, JupyterHub, and other Jupyter word marks are trademarks of LF Charities, of which Project Jupyter
is a part. All rights in those marks are reserved to LF Charities. [Julia](https://julialang.org/) is a trademark of
NumFOCUS, Inc. R is a trademark of the R Foundation for Statistical Computing. Any use by Docker is for referential
purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
