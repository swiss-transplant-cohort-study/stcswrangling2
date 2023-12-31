#' Tailored analysis tables
#'
#'@param stcs A list containing the STCS data frame.
#'
#'@return A data frame.
#'
#'@details
#'
#'\code{tailored_organ()}: PK: \code{organkey}. Baseline and outcome of organs.
#'
#'@name tail_tbl


#'@export
#'@rdname tail_tbl
tailored_organ <- function(stcs){

  data_organkey(stcs) |>
    add_var(stcs,c("soaskey","organ","tpxdate"),from = "organ",by = "organkey") |>
    add_var(stcs,c("patientkey","tpx","soascaseid"),from = "transplantation",by = "soaskey") |>
    add_var(stcs,c("patid","sex","yob"),from = "patient",by = "patientkey") |>
    select(all_of(c("organkey","soaskey","patientkey","patid","soascaseid","tpxdate","organ","tpx","sex","yob")))

}

#'@export
#'@rdname tail_tbl
#'@importFrom dplyr slice_max slice_min summarise
tailored_patientsurvival <- function(stcs){
  stcs$patient |>
    select(all_of(c("patientkey","enrollment_date"))) |>
    add_var(stcs,.var = "deathdate",from ="stop",by = "patientkey",.filter = !is.na(!!sym("deathdate"))) |>
    left_join(
      stcs$stop |>
        filter(!is.na(!!sym("dropoutdate"))) |>
        group_by(!!sym("patientkey")) |>
        slice_min(!!sym("dropoutdate")) |>
        select(all_of(c("patientkey","first_dropoutdate"="dropoutdate","first_dropoutdateaccuracy"="dropoutdateaccuracy"))),
      by = "patientkey",relationship = "one-to-one") |>
    add_var(stcs,.var = c("last_dropoutdate"="dropoutdate","last_dropoutdateaccuracy"="dropoutdateaccuracy"),
            from ="stop",by = "patientkey",.filter = is.na(!!sym("backstcsdate"))&!is.na(!!sym("dropoutdate"))) |>
    # add_var(stcs,.var = c("lastalivedate"),
    #         from ="stop",by = "patientkey",.filter = !is.na(!!sym("lastalivedate")))
    left_join(
      stcs$patientlongitudinal |>
        select(all_of(c("patientkey","assdate","patlongkey"))) |>
        group_by(!!sym("patientkey")) |>
        slice_max(!!sym("assdate")) |>
        summarise("last_assdate"=unique(!!sym("assdate")),
                  "last_patlongkeys" = paste(!!sym("patlongkey"), collapse = ",")),
      by = "patientkey",relationship = "one-to-one") |>
    left_join(
      stcs$patientdisease |>
        filter(!!sym("disease_category")=="Infection") |>
        group_by(!!sym("patientkey")) |>
        slice_max(!!sym("date")) |>
        summarise("lastinf_date"= unique(!!sym("date")),
                  "lastinf_diseasekeys" = paste(!!sym("diseasekey"), collapse = ",")),
      by = "patientkey",relationship = "one-to-one") |>
    left_join(
      stcs$organ |>
        select(all_of(c("patientkey","organkey"))) |>
        add_var(stcs,c("glodate"="date"),from = "graftloss", by = "organkey") |>
        group_by(!!sym("patientkey")) |>
        filter(any(!is.na(!!sym("glodate")))) |>
        summarise("first_glodate" = min(!!sym("glodate"),na.rm = T),
                  "laststcs_glodate" = max(!!sym("glodate"))),
      by = "patientkey",relationship = "one-to-one") |>
    add_var(stcs,"cutoff_date")

}


#'@export
#'@importFrom stringr str_starts
#'@rdname tail_tbl
tailored_psq <- function(stcs){

  Reduce(\(x,y){left_join(x,y,by = c("psqkey","patientkey"),relationship = "one-to-one")},
         lapply(stcs[str_starts(names(stcs),"psq")],psq_wide))

}


## PRIVATE ----

#' @importFrom tidyr pivot_wider
#' @importFrom dplyr ungroup group_by n across
#' @importFrom tidyselect where
#' @importFrom stringr str_pad
psq_wide <- function(x, .key = c("patientkey","psqkey")){

  stopifnot("The data frame must contains a psqkey." = all(.key %in%colnames(x)))
  stopifnot("The data frame must not contains a variable named rowid."= !".rowid"%in%colnames(x))

  out <-
    x |>
    group_by(across(all_of(.key))) |>
    mutate(".rowid" = seq_len(n())) |>
    ungroup()

  if(max(out[[".rowid"]])==1){
    out |>
      select(-all_of(".rowid"))
  }else{
    out |>
      mutate(".rowid" = as.character(!!sym(".rowid"))) |>
      mutate(".rowid" = str_pad(!!sym(".rowid"),
                                width = max(nchar(!!sym(".rowid"))),
                                pad="0")) |>
      group_by(across(all_of(.key))) |>
      pivot_wider(names_from = !!sym(".rowid"),
                  values_from = -all_of(c(.key,".rowid")),
                  names_glue = "{.value}_{.rowid}") |>
      ungroup() |>
      select(-where(\(x){all(is.na(x))}))

  }

}

