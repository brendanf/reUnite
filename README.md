# reannotate
Reannotated RDP fungal training set, Warcup, and Unite databases to use uniform taxonomic classifications.

Classifications are intended to match those used by the Unite database as much as possible.
This has been accomplished mostly by matching taxon names in the existing databases with those given in the proposed scheme of [Tedersoo (2017)](https://doi.org/10.1101/240929).
For certain groups, the existing databases are not specific enough to be directly mapped,
often because of taxonomic "splitting" since they were compiled, 
so taxonomic annotations are downloaded from NCBI.
The groups for which this is done in the current version is:

 - Protista (Unite)
 - Non-Fungi (RDP training set)
 - *Lactarius* (RDP)
 - *Sebacina* (RDP)

Some additional changes are made by hand using the `reference/*.pre.sed` files.
These include a few updates to Tedersoo's taxonomy.

Lists of all changed taxonomy for each database are found in `output/*.changes`.

# To use
Download the `.fasta.gz` files in the `output/` directory.
They are preformatted to use with SINTAX (in [USEARCH](https://www.drive5.com/usearch/)/[VSEARCH](https://github.com/torognes/vsearch))
or the Naïve Bayesian Classifier as implemented in [DADA2](http://benjjneb.github.io/dada2/).

# To (re)build
Clone the repository.

The build is managed by a combination of [Snakemake](https://snakemake.readthedocs.io/) and [Drake](https://github.com/ropensci/drake).
The easiest way to manage dependencies is `conda`.

```sh
snakemake --use-conda
```

Otherwise, you can manually install all of the packages listed in `config/drake.yaml`, and then do
```sh
snakemake
```

An internet connection is required.
NCBI queries are much more reliable if you have an ENTREZ key saved in a file `ENTREZ_KEY` in the root directory.
