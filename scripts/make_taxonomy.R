library(futile.logger)
if (file.exists("ENTREZ_KEY")) {
  Sys.setenv(ENTREZ_KEY = readLines("ENTREZ_KEY"))
}

# define or input file names and parameters
if (interactive()) {
  flog.info("Creating drake plan in interactive session...")
  library(here)
  r_dir <- "scripts"
  config_dir <- "config"
  ref_dir <- "reference"
  out_dir <- "output"
  tedersoo_file <- file.path(ref_dir, "Tedersoo_Eukarya_classification.xlsx")
  tedersoo_add_file <- file.path(ref_dir, "tedersoo_additions.xlsx")
  tedersoo_patch_file <- file.path(ref_dir, "tedersoo.pre.sed")
  regions_file <- file.path(config_dir, "regions.csv")
} else if (exists("snakemake")) {
  flog.info("Creating drake plan in snakemake session...")
  r_dir <- snakemake@config$rdir
  ref_dir <- snakemake@config$refdir
  out_dir <- snakemake@config$outdir
  tedersoo_file <- snakemake@input$tedersoo
  tedersoo_add_file <- snakemake@input$tedersoo_add
  tedersoo_patch_file <- snakemake@input$tedersoo_patch
  regions_file <- snakemake@input$regions
  outputs <- snakemake@output
  logfile <- file(snakemake@log[[1]], open = "at")
  sink(logfile, type = "output", split = TRUE)
  sink(logfile, type = "message")
} else {
  flog.error("Can't find Snakemake object in non-interactive session!")
  stop()
}

library(magrittr)
library(drake)
library(taxize)

source(file.path(r_dir, "taxonomy.R"))
source(file.path(r_dir, "parallel_helpers.R"))

setup_log("translate_references")

# Ranks present in the file describing the Tedersoo system.
tedersoo_ranks <- c("kingdom", "subkingdom", "phylum", "subphylum", "class",
                    "order", "family", "genus")

# The reference DBs and which format their headers use.
dbs <- readr::read_csv(file.path("config", "remotes.csv")) %>%
  dplyr::mutate(header_file = file.path("reference", paste0(db, ".fasta.gz")),
                patch_file = file.path("reference", paste0(db, ".pre.sed")))

db_meta <- dbs %>%
  dplyr::mutate(
    raw_header = rlang::syms(paste0("raw_header_", db)),
    sub_db = stringr::str_remove(db, paste0("^", header_format, "_"))
  ) %>%
  split.data.frame(.$header_format)

# Which regions each DB is applicable to
regions = readr::read_csv(regions_file, col_types = "cc") %>%
  tidyr::separate_rows(reference, sep = ", ?")


# Create names for the outputs
db_out <- dplyr::select(regions, reference) %>%
  dplyr::filter(complete.cases(.)) %>%
  unique() %>%
  tidyr::separate(col = reference, into = c("db", "region"), sep = "\\.") %>%
  tidyr::crossing(method = c("dada2", "sintax")) %>%
  dplyr::mutate(new_header = paste0("new_header_", db) %>%
                  rlang::syms(),
                fasta_in = file.path(ref_dir, paste( db, "fasta.gz",
                                                     sep = ".")),
                fasta_out = file.path(out_dir, paste(db, region, method,
                                                     "fasta.gz", sep = "."))) %>%
  dplyr::left_join(dbs, by = "db")

# Create the drake plan
# Targets will be created if they are missing or if their
# prerequisites have changed.
plan <- drake_plan(
  # read headers from the reference database fasta files
  raw_header = target(
    read_header(header_file = file_in(header_file),
                patch_file = file_in(patch_file),
                format = header_format),
    transform = map(.data = !!dbs,
                    .id = db)
    ),

  # the rdp training set does not have fully annotated taxonomy for nonfungi,
  # so these need to be looked up
  # find the accession numbers representing nonfungi in the RDP database
  # We will also do the same for Protista in Unite, Sebacinales in RDP,
  # and Lactarius in both RDP and Warcup, because these are cases where the
  # taxonomy has recently been split.
  rdp_nf_accno =
    dplyr::filter(raw_header_rdp_train, !grepl("Fungi", classifications)) %$%
    accno %>%
    unique(),

  unite_prot_accno =
    dplyr::bind_rows(raw_header_unite_single, raw_header_unite_nosingle) %>%
    dplyr::filter(startsWith(classifications, "Protista"),
                  !startsWith(accno, "UDB")) %$%
    accno %>%
    unique(),

  rdp_lac_accno =
    dplyr::filter(raw_header_rdp_train, grepl("Lactarius", classifications)) %$%
    accno %>%
    unique(),

  rdp_seb_accno =
    dplyr::filter(raw_header_rdp_train, grepl("Sebacinales", classifications)) %$%
    accno %>%
    unique(),

  rdp_nf_taxdata =
    target(
      lookup_tax_data_fragile(rdp_nf_accno, type = "seq_id"),
      transform = split(rdp_nf_accno, slices = 50),
      retries = 1
    ),

  rdp_seb_taxdata =
    target(
      lookup_tax_data_fragile(rdp_seb_accno, type = "seq_id"),
      retries = 1
    ),

  rdp_lac_taxdata =
    target(
      lookup_tax_data_fragile(rdp_lac_accno, type = "seq_id"),
      retries = 1
    ),

  unite_prot_taxdata =
    target(
      lookup_tax_data_fragile(unite_prot_accno, type = "seq_id"),
      transform = split(unite_prot_accno, slices = 15),
      retries = 1
    ),

  rdp_nf_ncbiheader =
    target(
      purrr::map_dfr(
          list(rdp_nf_taxdata),
          accno_c12n_table,
          patch_file = file_in(!!file.path(ref_dir, "ncbi.pre.sed"))
      ),
      transform = combine(rdp_nf_taxdata)
    ),

  rdp_seb_ncbiheader = accno_c12n_table(
      rdp_seb_taxdata,
      patch_file = file_in(!!file.path(ref_dir, "ncbi.pre.sed"))
  ),

  rdp_lac_ncbiheader = accno_c12n_table(
      rdp_lac_taxdata,
      patch_file = file_in(!!file.path(ref_dir, "ncbi.pre.sed"))
  ),

  unite_prot_ncbiheader =
    target(
      purrr::map_dfr(
          list(unite_prot_taxdata),
          accno_c12n_table,
          patch_file = file_in(!!file.path(ref_dir, "ncbi.pre.sed"))
      ),
      transform = combine(unite_prot_taxdata)
    ),

  rdp_nf_taxa =
    target(
      list(rdp_nf_taxdata) %>%
        purrr::map_dfr(~ .$data$tax_data) %>%
        unique(),
      transform = combine(rdp_nf_taxdata)
    ),

  rdp_seb_taxa = rdp_seb_taxdata$data$tax_data,

  rdp_lac_taxa = rdp_lac_taxdata$data$tax_data,

  unite_prot_taxa =
    target(
      list(unite_prot_taxdata) %>%
        purrr::map_dfr(~ .$data$tax_data) %>%
        unique(),
      transform = combine(unite_prot_taxdata)
    ),

  # Parse Tedersoo's classification
  tedersoo_class =
    read_classification_tedersoo(
      file_in(!!tedersoo_file),
      file_in(!!tedersoo_add_file),
      file_in(!!tedersoo_patch_file)
    ),

  # Remove taxa at unnecessary ranks.
  rdp_nf_reduced =
    target(
      reduce_ncbi_taxonomy(
        rdp_nf_ncbiheader,
        rdp_nf_taxa,
        ranks = c("kingdom", "phylum", "class", "order",
                  "family", "genus"),
        keytaxa = unique(tedersoo_class$taxon_names)
      )
    ),

  rdp_seb_reduced =
    reduce_ncbi_taxonomy(
      rdp_seb_ncbiheader,
      rdp_seb_taxa,
      ranks = c("kingdom", "phylum", "class", "order",
                "family", "genus"),
      keytaxa = unique(tedersoo_class$taxon_names)
    ),

  rdp_lac_reduced =
    reduce_ncbi_taxonomy(
      rdp_lac_ncbiheader,
      rdp_lac_taxa,
      ranks = c("kingdom", "phylum", "class", "order",
                "family", "genus"),
      keytaxa = unique(tedersoo_class$taxon_names)
    ),

  unite_prot_reduced =
    reduce_ncbi_taxonomy(
      unite_prot_ncbiheader,
      unite_prot_taxa,
      ranks = c("kingdom", "phylum", "class", "order",
                "family", "genus"),
      keytaxa = unique(tedersoo_class$taxon_names)
    ) %>%
    dplyr::mutate_at(
      "classifications",
      stringr::str_replace_all,
      "Bacillariophyta",
      "Stramenopiles;Bacillariophyceae"
    ),

  # Combine the classifications from the taxa that we looked up from NCBI
  # with the original ones from the files.
  reduced_header_rdp_train = target(
    raw_header %>%
      dplyr::filter(!duplicated(accno)) %>%
      dplyr::left_join(
        dplyr::select(rdp_nf_reduced, accno, c_nf = classifications),
        by = "accno"
      ) %>%
      dplyr::left_join(
        dplyr::select(rdp_seb_reduced, accno, c_seb = classifications),
        by = "accno"
      ) %>%
      dplyr::left_join(
        dplyr::select(rdp_lac_reduced, accno, c_lac = classifications),
        by = "accno"
      ) %>%
      dplyr::mutate(
        classifications =
          dplyr::coalesce(c_seb, c_lac, c_nf, classifications) %>%
          reduce_taxonomy()
      ) %>%
      dplyr::select(-c_lac, -c_seb, -c_nf),
    transform = map(raw_header = raw_header_rdp_train, db = "rdp_train", .tag_out = reduced_header, .id = FALSE)
  ),

  reduced_header_unite = target(
    raw_header %>%
      dplyr::filter(!duplicated(accno)) %>%
      dplyr::left_join(
        dplyr::select(unite_prot_reduced, accno, c_prot = classifications),
        by = "accno"
      ) %>%
      dplyr::mutate(
        classifications =
          dplyr::coalesce(c_prot, classifications) %>%
          reduce_taxonomy()
      ) %>%
      dplyr::select(-c_prot),
    transform = map(.data = !!db_meta$unite, .tag_out = reduced_header, .id = sub_db)
  ),

  reduced_header_warcup = target(
    raw_header %>%
      dplyr::filter(!duplicated(accno)) %>%
      dplyr::mutate(
        classifications = reduce_taxonomy(classifications)
      ),
    transform = map(raw_header = raw_header_warcup, db = "warcup", .tag_out = reduced_header, .id = FALSE)
  ),

  reduced_header_silva = target(
      raw_header %>%
          dplyr::filter(!duplicated(accno)) %>%
          dplyr::mutate(
              classifications = reduce_taxonomy(classifications)
          ),
      transform = map(.data = !!db_meta$silva, .tag_out = reduced_header, .id = sub_db)
  ),

  # parse classification from the headers
  class = target(
    reduced_header$classifications %>%
      unique() %>%
      taxa::parse_tax_data() %>%
      taxa::get_data_frame(c("taxon_names", "classifications")),
    transform = map(reduced_header, .id = db)
  ),

  # translate taxonomy to Tedersoo's system.
  new_header = target(
    translate_taxonomy(reduced_header,
                       class,
                       tedersoo_class,
                       file_out(!!file.path(out_dir, paste0(db, ".changes2")))) %>%
    dplyr::mutate_at("classifications", regularize_taxonomy,
                     rank_in = tedersoo_ranks) %>%
        dplyr::mutate_at("classifications", taxonomy_to_na),
    transform = map(class, .id = db)
  ),

  # Output files in formats suitable for SINTAX and DADA2.
  write = target(
    replace_header(file_in(fasta_in), file_out(fasta_out), new_header,
                   in_format = header_format, out_format = method,
                   patch_file = file_in(patch_file)),
    transform = map(.data = !!db_out,
                      .id = c(db, region, method))
  ),

  changes = target(
    dplyr::left_join(
      raw_header,
      new_header,
      by = c("index", "accno"),
      suffix = c(".old", ".new")
    ) %>%
      dplyr::mutate(
        classifications.old = sub(
          classifications.old,
          pattern = "^([^;]+;)([^;]+;)([^;]+;)([^;]+;)([^;]+;)([^;]+;)([^;]+;)([^;]+)(;[^;]*)?$",
          replacement = "\\1\\2\\4\\6\\7\\8"
        ) %>%
          sub(
            pattern = "^(([^;]+;){5}[^;]+);.*$",
            replacement = "\\1"
          ) %>%
          gsub(
            pattern = "_(phy|cls|ord|fam)_",
            replacement = ""
          ) %>%
          chartr(old = " ", new = "_") %>%
          gsub(
            pattern = "_incertae",
            replacement = "_Incertae"
          )
      ) %>%
      dplyr::filter(classifications.old != classifications.new) %>%
      dplyr::mutate(
        suffix = purrr::map2_chr(
          classifications.old,
          classifications.new,
          ~ Biobase::lcSuffix(c(.x, .y))
        ) %>%
          sub("^(([^A-Z;][^;]*)?;)?[A-Z][^;]+", "", .) %>%
          ifelse(grepl(";", .), ., "")
      ) %>%
      dplyr::mutate(
        classifications.old = ifelse(
          nchar(suffix) > 0,
          stringi::stri_replace_last_fixed(
            classifications.old,
            suffix,
            ""
          ),
          classifications.old
        ),
        classifications.new = ifelse(
          nchar(suffix) > 0,
          stringi::stri_replace_last_fixed(
            classifications.new,
            suffix,
            ""
          ),
          classifications.new
        )
      ) %>%
      dplyr::group_by(classifications.old, classifications.new) %>%
      dplyr::summarize(accnos = paste(accno, collapse = ",")) %>%
      readr::write_tsv(file_out(!!file.path(out_dir, paste0(db, ".changes")))),
    transform = map(raw_header, new_header, db, .id = db)
  ),
  trace = TRUE
)

# Make sure that the outputs of the plan are also the outputs of the
# Snakemake rule
outfiles <- as.character(plan$command) %>%
  stringr::str_match_all('file_out\\("([^"]+)"\\)') %>%
  purrr::keep(~length(.) > 0) %>%
  purrr::map(2) %>%
  unlist() %>%
  unique()

if (exists("outputs")) {
  flog.info("outputs: %s", paste(outputs, collapse = ", "))
  flog.info("outfiles: %s", paste(outfiles, collapse = ", "))
  assertthat::assert_that(all(outputs %in% outfiles))
}

# Do the work
make(plan, retries = 2)

# make sure to touch all the outputs so that Snakemake will be happy.
if (exists("outputs")) {
  for (o in outputs) Sys.setFileTime(o, Sys.time())
}
