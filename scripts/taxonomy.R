#' Parse taxonomy from FASTA headers in different formats.
#'
#' @param header_file (`character` string or anything with `names()`) either the
#'     path of a FASTA file to extract the headers from, or an object
#'     representing the FASTA file, where `names()` returns the headers (for
#'     instance a named character vector or a `Biostrings::DNAStringSet`)
#' @param patch_file (`character` string) path to a file which will be used to
#'     patch the taxonomy in the headers using `patch_header()`
#' @param format (`character` string) which header format to read.
#'     Supported values are `"rdp"`, `"unite"`, and `"silva"`.
#'
#' @return a `tibble` with columns "index" (`integer`), "accno" (`character`),
#'     and "classifications" (`character`)
#' @export
#'
#' @examples
read_header <- function(header_file, patch_file, format) {
  switch(format,
    rdp = read_header_rdp(header_file, patch_file),
    unite = read_header_unite(header_file, patch_file),
    silva = read_header_silva(header_file, patch_file),
    stop("unknown reference database format: ", format)
  )
}

# parse taxonomy from RDP-style FASTA headers
# >(accession number)   Root;(kingdom);(phylum);(class);(order);(family);(genus);(species?)
read_header_rdp <- function(header_file, patch_file) {
  header_file <- if (is.character(header_file)) {
    Biostrings::readDNAStringSet(header_file)
  } else {
    header_file
  }
  header_file %>%
    names() %>%
    patch_taxonomy(patch_file) %>%
    stringr::str_match("(gi\\|\\d+\\|e?[gm]b\\|)?([A-Z]+_?[0-9]+)[.\\d|-]*[:space:]+Root;(.+)") %>%
    {tibble::tibble(index = seq_len(nrow(.)),
                    accno = .[,3],
                    classifications = .[,4])}
}

# parse taxonomy from Unite-style FASTA headers
# >(name)|(accno)|(species hypothesis)|(category)|k__(kingdom);p__(phylum);c__(class);o__(order);f__(family);g__(genus);s__(species)
read_header_unite <- function(header_file, patch_file) {
  header_file <- if (is.character(header_file)) {
    Biostrings::readDNAStringSet(header_file)
  } else {
    header_file
  }
  header_file %>%
    names() %>%
    patch_taxonomy(patch_file) %>%
    stringr::str_match("[^|]\\|([A-Z]+_?[0-9]+)\\|[^|]+\\|re[pf]s(_singleton)?\\|(([kpcofgs]__[-\\w.]+;?){7})") %>%
    {tibble::tibble(index = seq_len(nrow(.)),
                    accno = .[,2],
                    classifications = .[,4])} %>%
    dplyr::mutate_at("classifications",
                     stringr::str_replace_all,
                     "[kpcofgs]__", "") %>%
    dplyr::mutate_at("classifications", stringr::str_replace_all,
                     ";unidentified", "")
}

# parse taxonomy from Silva-style FASTA header
# > (accno).(start).(end) (Domain);(rest);(of);(taxonomy);(with);(variable);(number);(of);(ranks)
read_header_silva <- function(header_file, patch_file) {
    header_file <- if (is.character(header_file)) {
        Biostrings::readDNAStringSet(header_file)
    } else {
        header_file
    }
    header_file <- names(header_file)

    header_file %>%
        patch_taxonomy(patch_file) %>%
        tibble::tibble(header = .) %>%
        tidyr::extract(
            col = header,
            into = c("accno", "classifications"),
            regex = "([^.]+)\\.[0-9]+\\.[0-9]+ +(.+)"
        ) %>%
        dplyr::mutate(
            classifications = classifications %>%
                stringr::str_remove_all(";[^;]*(uncultured|unknown|unidentified|[Ii]ncertae[_ ][Ss]edis)[^;]*"),
            index = seq.int(dplyr::n())
        )
}



write_taxonomy <- function(taxonomy, fasta, outfile, format) {
    switch(format,
           dada2 = write_taxonomy_dada2(taxonomy, fasta, outfile),
           sintax = write_taxonomy_sintax(taxonomy, fasta, outfile),
           stop("unknown taxonomy format: ", format)
    )
}

write_taxonomy_dada2 <- function(taxonomy, fasta, outfile) {
    if (is.character(fasta)) {
        fasta <- Biostrings::readDNAStringSet(fasta)
    }
    fasta <- fasta[!is.na(taxonomy$classifications)]

    taxonomy %>%
        dplyr::filter(!is.na(classifications)) %$%
        set_names(fasta, classifications) %>%
        Biostrings::writeXStringSet(outfile, compress = endsWith(outfile, ".gz"))
}

write_taxonomy_sintax <- function(taxonomy, fasta, outfile) {
    if (is.character(fasta)) {
        fasta <- Biostrings::readDNAStringSet(fasta)
    }
    fasta <- fasta[!is.na(taxonomy$classifications)]

    taxonomy %>%
        dplyr::filter(!is.na(classifications)) %>%
        dplyr::mutate_at("classifications", stringr::str_replace,
                         "([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)",
                         "tax=k:\\1,p:\\2,c:\\3,o:\\4,f:\\5,g:\\6") %$%
        set_names(fasta, classifications) %>%
        Biostrings::writeXStringSet(outfile, compress = endsWith(outfile, ".gz"))
}

replace_header <- function(in_fasta, out_fasta, new_header,
                           in_format, out_format,
                           patch_file) {
  fasta <- Biostrings::readDNAStringSet(in_fasta)
  old_header <- read_header(fasta, patch_file, in_format)
  assertthat::assert_that(all(old_header$accno %in% new_header$accno))
  new_header <- dplyr::select(old_header, accno) %>%
    dplyr::left_join(new_header, by = "accno")

  bad_classifications <- is.na(new_header$classifications) |
    startsWith(new_header$classifications, "Eukaryota") |
    startsWith(new_header$classifications, "Chromista") |
    startsWith(new_header$classifications, "Protista")

  fasta <- fasta[!bad_classifications]
  new_header <- new_header[!bad_classifications,]

  write_taxonomy(taxonomy = new_header, fasta = fasta, outfile = out_fasta,
                 format = out_format)
}

lookup_tax_data_fragile <- function(...) {
  tryCatch(
    taxa::lookup_tax_data(...),
    warning = function(e) stop("Failed to look up all accession numbers.")
  )
}

accno_c12n_table <- function(tax_data, patch_file = NULL) {
    dplyr::left_join(
        tibble::tibble(
            accno = tax_data$data$query_data,
            taxon_ids = names(tax_data$data$query_data)
        ),
        tax_data$get_data_frame(c("taxon_ids", "classifications")),
        by = "taxon_ids"
    ) %>%
        dplyr::mutate_at("classifications", patch_taxonomy, patch_file)
}

reduce_ncbi_taxonomy <- function(taxonomy, taxa, ranks, keytaxa) {
  dplyr::filter(
      taxa,
      !ncbi_rank %in% ranks,
      !ncbi_name %in% keytaxa
  ) %$%
  dplyr::mutate_at(taxonomy, "classifications",
                   stringi::stri_replace_all_fixed,
                   pattern = paste0(ncbi_name, ";"),
                   replacement = "",
                   vectorize_all = FALSE) %>%
  dplyr::mutate_at("classifications", stringr::str_replace_all, ";$", "")
}

reduce_taxonomy <- function(taxonomy) {
    # take only the first capitalized word at each taxonomic level
    stringr::str_replace_all(taxonomy,
                         "(^|;)[^A-Z;]*([A-Z]+[a-z0-9]+)[^;]*",
                         "\\1\\2") %>%
    # remove all-lower-case entries (typically "uncultured soil fungus", etc.)
    stringr::str_replace_all("(^|;)[^A-Z;]+($|;)", "\\1\\2") %>%
    # remove extra semicolons
    stringr::str_replace_all(";+", ";") %>%
    stringr::str_replace_all("(^;|;$)", "") %>%
    # remove repeated taxa (due to removed incertae sedis or species epithet)
    stringr::str_replace_all("([A-Z]+[a-z0-9]+)(;\\1)+(;|$)", "\\1\\3")
}

translate_taxonomy <- function(taxonomy, c12n, reference, change_file) {
    if (!dir.exists(dirname(change_file))) dir.create(dirname(change_file))
    change_file <- file(change_file, open = "wt")
    on.exit(close(change_file))

    c12n <- c12n %>%
        dplyr::mutate(n_supertaxa = stringr::str_count(classifications, ";")) %>%
        dplyr::group_split(n_supertaxa)

    for (i in seq_along(c12n)) {
        flog.info("Translating %i taxa at level %i.", nrow(c12n[[i]]), i)
        replacements <- c12n[[i]] %>%
            dplyr::select(taxon_names, classifications) %>%
            dplyr::inner_join(reference, by = "taxon_names",
                              suffix = c("_src", "_ref")) %>%
            dplyr::group_by(classifications_src) %>%
            dplyr::mutate(mismatch = all(classifications_src != classifications_ref)) %>%
            dplyr::filter(mismatch) %>%
            dplyr::mutate(
                dist = stringdist::stringdist(
                    classifications_src,
                    classifications_ref,
                    method = "jaccard",
                    q = 5
                )
            ) %>%
            dplyr::arrange(dist, .by_group = TRUE) %>%
            dplyr::summarize(classifications_ref = dplyr::first(classifications_ref)) %>%
            dplyr::mutate(
                prefix = purrr::map2(
                    classifications_src,
                    classifications_ref,
                    ~Biobase::lcPrefix(c(.x, .y))
                ) %>%
                    stringr::str_remove("[^;]+$") %>%
                    ifelse(. == "", "(root)", .),
                classout_src = stringr::str_remove(
                    classifications_src,
                    paste0("^", prefix)
                ),
                classout_ref = stringr::str_remove(
                    classifications_ref,
                    paste0("^", prefix)
                )
            ) %>%
            dplyr::mutate_at(
                c("prefix", "classout_src", "classout_ref"),
                stringr::str_remove_all,
                pattern = "[^;]+[iI]ncertae[ _][Ss]edis;"
            ) %>%
            dplyr::mutate_at("classifications_src", paste0, "(;|$)") %>%
            dplyr::mutate_at("classifications_ref", paste0, "$1")
        if (nrow(replacements)) {
            dplyr::filter(replacements, classout_src != classout_ref) %>%
                glue::glue_data("{prefix} : {classout_src} -> {classout_ref}") %>%
                writeLines(con = change_file)
            taxonomy$classifications <-
                stringi::stri_replace_all_regex(taxonomy$classifications,
                                                replacements$classifications_src,
                                                replacements$classifications_ref,
                                                vectorize_all = FALSE)
            for (j in seq_along(c12n)) {
                if (j < i) next
                c12n[[j]]$classifications <-
                    stringi::stri_replace_all_regex(c12n[[j]]$classifications,
                                                    replacements$classifications_src,
                                                    replacements$classifications_ref,
                                                    vectorize_all = FALSE)
            }
        }
    }
    flog.info("Uniquifying taxonomy.")
    uniquify_taxonomy(taxonomy, dplyr::bind_rows(c12n))
}

uniquify_taxonomy <- function(taxonomy, c12n) {
  # finding duplicates is much faster than checking whether the
  # classification is present in the taxonomy, so do that first.
  taxdupes <- unique(c12n$taxon_names[duplicated(c12n$taxon_names)])
  flog.info("Found %i initial duplicated taxon names. Searching reference...",
            length(taxdupes))
  c12n <-
    dplyr::filter(c12n, taxon_names %in% taxdupes) %>%
    dplyr::filter(purrr::map_lgl(classifications,
                                 ~any(stringi::stri_detect_fixed(
                                   taxonomy$classifications, .))))
  # now we only need the ones where duplicates are actually present.
  taxdupes <- c12n$taxon_names[duplicated(c12n$taxon_names)]
  flog.info("Found %i duplicated taxon names in reference.", length(taxdupes))
  if (length(taxdupes) > 0) {
    dplyr::filter(c12n, taxon_names %in% taxdupes) %>%
      dplyr::mutate(kingdom = stringr::str_extract(classifications, "^[^;]+")) %>%
      dplyr::filter(kingdom == "Metazoa") %>%
      dplyr::mutate(replacement = paste0(classifications, "(Metazoa)$1"),
                    pattern = paste0(classifications, "(;|$)")) %$%
      dplyr::mutate_at(taxonomy,
                       "classifications",
                       stringi::stri_replace_all_regex,
                       pattern = pattern,
                       replacement = replacement,
                       vectorize_all = FALSE)
  } else {
    taxonomy
  }

}

# Apply a patch file (in sed regular expression format) to classification strings

patch_taxonomy <- function(taxonomy, patch_file) {
  assertthat::assert_that((assertthat::is.string(patch_file)
                           && file.exists(patch_file))
                          || is.null(patch_file))
  if (is.null(patch_file)) return(taxonomy)

  replace <- readLines(patch_file) %>%
    stringr::str_subset("^s/") %>%
    stringr::str_match("s/(.+)/(.+)/g?")
  if (nrow(replace) == 0) return(taxonomy)
  for (n in seq_len(nrow(replace))) {
    taxonomy <- gsub(replace[n, 2], replace[n,3], taxonomy)
  }
  taxonomy
}

patch_taxa <- function(c12n, patch_file) {
  assertthat::assert_that((assertthat::is.string(patch_file)
                           && file.exists(patch_file))
                          || is.null(patch_file))
  if (!is.null(patch_file)) {
    patch <- readr::read_csv(patch_file,
                             col_types = readr::cols(.default = readr::col_character()))
    assertthat::assert_that(assertthat::has_name(patch, "pattern"),
                            assertthat::has_name(patch, "replacement"))
    c12n <- stringi::stri_replace_all_regex(c12n,
                                            pattern = patch$pattern,
                                            replacement = patch$replacement,
                                            vectorize_all = FALSE)
  }
  return(c12n)
}

# Removes unnecessary ranks from taxonomy, ensures intermediate missing ranks are "incertae sedis" and trailing missing ranks are "unidentified"

regularize_taxonomy <- function(taxonomy, rank_in,
                                rank_out = c("kingdom", "phylum", "class",
                                             "order", "family", "genus"),
                                sep = ";") {
  taxonomy <-
    stringr::str_split_fixed(taxonomy,
                             n = length(rank_in),
                             pattern = sep) %>%
    set_colnames(rank_in) %>%
    tibble::as_tibble() %>%
    dplyr::select(!!!rank_out) %>%
    dplyr::mutate_all(gsub, pattern = ".+[Ii]ncertae[_ ]sedis", replacement = "") %>%
    dplyr::mutate_all(dplyr::na_if, "")
  for (i in 1:(length(rank_out) - 2)) {
    taxonomy[[i + 1]] <- dplyr::coalesce(taxonomy[[i + 1]],
                                         paste0(taxonomy[[i]],
                                                "_Incertae_sedis"))
  }
  taxonomy <-
    dplyr::mutate_all(taxonomy,
                      stringr::str_replace,
                      "(_Incertae_sedis)+",
                      "_Incertae_sedis")
  for (i in (length(rank_out) - 1):2) {
    taxonomy[[i]] <- ifelse(is.na(taxonomy[[i + 1]]) &
                              endsWith(taxonomy[[1]], "_Incertae_sedis"),
                            NA_character_,
                            taxonomy[[i]])
  }
  for (i in 1:(length(rank_out) - 1)) {
    taxonomy[[i + 1]] <- dplyr::coalesce(taxonomy[[i + 1]],
                                         paste("unidentified",
                                               taxonomy[[i]],
                                               sep = "_"))
  }
  taxonomy %>%
    dplyr::mutate_all(stringr::str_replace,
                      "(unidentified_)+",
                      "unidentified_") %>%
    purrr::pmap_chr(paste, sep = ";")
}

read_classification_tedersoo <- function(file, patch_file = NULL) {
    readxl::read_xlsx(file) %>%
    dplyr::select(-subdomain) %>%
    # Remove duplicate taxa within one kingdom
    # Unless noted otherwise the choice of which to remove is based on
    # Index Fungorum (for Fungi) or GBIF (for other organisms)
    dplyr::filter(
      !(genus == "Rhodotorula" & family == "unspecified"),
      !(genus == "Verticillium" & family == "unspecified")#,
      # !(genus == "Automolus" & class == "Insecta"),
      # !(genus == "Clania" & order = "Lepidoptera"),
      # !(genus == "Euxinia" & class == "Malacostraca"),
      # !(genus == "Keijia" & class == "Arachnida"),
      # !(genus == "Napo" & order == "Hymenoptera"),
      # !(genus == "Oxyacanthus" & order == "Amphipoda"),
      # !(genus == "")
    ) %>%
    # dplyr::mutate(
    #   genus = ifelse((genus == "Eutrapela" & order = "Coleoptera"),
    #                  "Chromomoea",
    #                  genus) %>%
    #     ifelse((genus == "Ichthyophaga" & phylum = "Platyhelminthes"),
    #            "Piscinquilinus",
    #            genus)
    # )
    dplyr::mutate_all(dplyr::na_if, "unspecified") %>%
    dplyr::mutate(
      kingdom = dplyr::coalesce(kingdom,
                                "Eukaryota_reg_Incertae_sedis"),
      subkingdom = dplyr::coalesce(subkingdom,
                                   paste0(kingdom, "_subreg_Incertae_sedis")),
      phylum = dplyr::coalesce(phylum,
                               paste0(subkingdom, "_phy_Incertae_sedis")),
      subphylum = dplyr::coalesce(subphylum,
                                  paste0(phylum, "_subphy_Incertae_sedis")),
      class = dplyr::coalesce(class,
                              paste0(subphylum, "_cl_Incertae_sedis")),
      order = dplyr::coalesce(order,
                              paste0(class, "_ord_Incertae_sedis")),
      family = dplyr::coalesce(family,
                               paste0(order, "_fam_Incertae_sedis"))
    ) %>%
    dplyr::mutate_all(sub,
                      pattern = "(_(sub)?(reg|phy|cl|ord)_Incertae_sedis)+(_(sub)?(reg|phy|cl|ord|fam)_Incertae_sedis$)",
                      replacement = "\\4") %>%
    # The subphylum of Variosea is sometimes missing.
    # The main text says that it should be in Mycetozoa
    dplyr::mutate(subphylum = ifelse(class == "Variosea",
                                     "Mycetozoa",
                                     subphylum),
                  # Craniata is a phylum;
                  # Craniatea is a class in Brachiopoda
                  class = ifelse(class == "Craniata",
                                 "Craniatea",
                                 class)) %>%
    unique() %>%
    taxa::parse_tax_data(class_cols = 1:8,
                         named_by_rank = TRUE) %>%
    taxa::get_data_frame(c("taxon_names", "classifications")) %>%
    dplyr::filter(!stringr::str_detect(taxon_names, "[Ii]ncertae[_ ]sedis")) %>%
    dplyr::mutate_at("classifications", patch_taxonomy, patch_file = patch_file)

}

