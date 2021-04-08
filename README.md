# Reannotate
#### Reannotated RDP, Silva, and Unite databases to use uniform taxonomic classifications.

The current version includes the following data sets:

#### [RDP](https://rdp.cme.msu.edu/misc/resources.jsp)

 - **rdp_train**: Fungal LSU training set version 11
 - **warcup**: Warcup ITS training set version 2

#### [Silva](https://www.arb-silva.de/documentation/release-138/)

 - **silva_parc**: LSU Parc version 138.1
 - **silva_ref**: LSU Ref version 138.1
 - **silva_nr99**: LSU Ref NR99 version 138.1

#### [Unite](https://unite.ut.ee/repository.php)

 - **unite_nosingle**: Unite with singletons set as RefS, all eukaryotes, version 8.2
 - **unite_single**: Unite with global and 97% singletons, all eukaryotes, version 8.2

## Classification

Classifications are intended to match those used by the Unite database as much as possible.
This has been accomplished mostly by matching taxon names in the existing databases with those given in the proposed scheme of [Tedersoo (2017)](https://doi.org/10.1101/240929).
This scheme is used because it uses uses the same taxonomic ranks across all eukaryotes.
Only the primary taxonomic ranks (Kingdom, Phylum, Class, Order, Family, Genus) are included.
Species annotations are also not included.

For certain groups, the existing databases are not specific enough to be directly mapped,
often because of taxonomic "splitting" since they were compiled, 
so taxonomic annotations are downloaded from NCBI.
The groups for which this is done in the current version is:

 - "Protista"" (Unite)
 - Non-Fungi (RDP training set)
 - *Lactarius* (RDP)
 - *Sebacina* (RDP)

Some additional changes are made by hand using the `reference/*.pre.sed` files.
These include a few updates to Tedersoo's taxonomy.

Lists of all changed taxonomy for each database are found in `output/*.changes`;
more summarized changes are found in `output/*.changes2`.

# To use
Download the `.fasta.gz` from the most recent [release], or from the `output/` directory for the most recent pre-release build.
There are preformatted versions for use with SINTAX (in [USEARCH](https://www.drive5.com/usearch/)/[VSEARCH](https://github.com/torognes/vsearch))
or the RDP Naïve Bayesian Classifier as implemented in [DADA2](http://benjjneb.github.io/dada2/).

The header format for SINTAX is:

```
>tax=k:kingdom,p:phylum,c:class,o:order,f:family,g:genus
```

The header format for DADA2 is:

```
>kingdom;phylum;class;order;family;genus
```

In both cases, all "unknown" classifications are truncated away; both SINTAX and DADA2 can accomodate this.
Intermediate classifications which are missing are given as the nearest non-missing supertaxon, followed by "`_Incertae_sedis`".

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
