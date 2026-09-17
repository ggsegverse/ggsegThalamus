# Create the thalamic nuclei atlases for ggseg
#
# Two published parcellations of the thalamus, from different modalities:
#
#   thalamus_hcp    Najdenovska et al. (2018), 7 nuclei groups per hemisphere,
#                   clustered from HCP diffusion MRI.
#   thalamus_thomas Su et al. (2019), 12 nuclei per hemisphere, segmented from
#                   white-matter-nulled MPRAGE.
#
# Both ship as labelled volumes on the FSL-MNI152 grid with no anatomical
# context, so as with the other MNI152 subcortical atlases in the ggsegverse
# they are embedded into the fsaverage5 aseg with
# prepare_subcortical_mni152(), and aseg_context() then demotes the
# surrounding brain to grey.
#
# Unlike the whole-subcortex atlases, these cover the thalamus alone, so only
# the aseg's thalamus is cleared. The default replaces every lumped
# subcortical structure, which would leave holes where the caudate, putamen,
# pallidum, hippocampus, amygdala and accumbens should still be drawn as grey
# anatomical context around the nuclei.
#
# Source: https://github.com/anniegbryant/subcortex_visualization
#   (atlas_info/MNI152NLin6Asym/Thalamus_HCP and Thalamus_THOMAS)
# References:
#   Najdenovska E, Aleman-Gomez Y, Battistella G, et al. (2018). In-vivo
#     probabilistic atlas of human thalamic nuclei based on diffusion-
#     weighted magnetic resonance imaging. Scientific Data 5:180270.
#     DOI: 10.1038/sdata.2018.270
#   Su JH, Thomas FT, Kasoff WS, et al. (2019). Thalamus Optimized Multi
#     Atlas Segmentation (THOMAS): fast, fully automated segmentation of
#     thalamic nuclei from structural MRI. NeuroImage 194:272-282.
#     DOI: 10.1016/j.neuroimage.2019.03.021
#
# Requires: ggseg.extra, ggseg.formats, FreeSurfer 7.4.1 with fsaverage5.
#
# Run with: Rscript data-raw/make_thalamus.R [hcp|thomas ...]

library(ggseg.extra)
library(ggseg.formats)

future::plan(future::sequential)
progressr::handlers("cli")
progressr::handlers(global = TRUE)

fs_home <- Sys.getenv("FREESURFER_HOME", "/Applications/freesurfer/7.4.1")
Sys.setenv(FREESURFER_HOME = fs_home)
Sys.setenv(SUBJECTS_DIR = file.path(fs_home, "subjects"))

data_raw <- here::here("data-raw")
source_dir <- file.path(data_raw, "source")

# Both atlases number from 1, colliding with the aseg ids they are stamped
# into. The shift has to clear those from below and stay under 1000 from
# above: ids in 1000-2999 are where an aparc+aseg keeps its cortical parcels,
# and a pipeline that finds parcels there reads them as the cortex and builds
# the brain silhouette out of them instead of the cortical ribbon.
id_offset <- 300L

# Only the thalamus is subdivided, so only the thalamus is cleared.
aseg_thalamus <- c(10L, 49L)

# Labels keep the identifiers the published lookup tables use, so a label
# still matches the source, and `region` falls out of them by the usual strip
# (lower case, hemisphere dropped). The spelled-out names go in a `name`
# column, keyed on region, for anything that prints a nucleus to a reader.
region_names <- list(
  hcp = c(
    "pulvinar" = "Pulvinar",
    "anterior" = "Anterior nuclei",
    "medio dorsal" = "Mediodorsal nucleus",
    "ventral latero dorsal" = "Ventral latero-dorsal nucleus",
    "central lateral lateral posterior medial pulvinar" = "Central lateral, lateral posterior and medial pulvinar nuclei",
    "ventral anterior" = "Ventral anterior nucleus",
    "ventral latero ventral" = "Ventral latero-ventral nucleus"
  ),
  thomas = c(
    "av" = "Anteroventral nucleus",
    "va" = "Ventral anterior nucleus",
    "vla" = "Ventral lateral anterior nucleus",
    "vlp" = "Ventral lateral posterior nucleus",
    "vpl" = "Ventral posterolateral nucleus",
    "pul" = "Pulvinar",
    "lgn" = "Lateral geniculate nucleus",
    "mgn" = "Medial geniculate nucleus",
    "cm" = "Centromedian nucleus",
    "md" = "Mediodorsal nucleus",
    "hb" = "Habenula",
    "mtt" = "Mammillothalamic tract"
  )
)

# One colour per nucleus, shared by the two sides, so a nucleus reads as the
# same thing on both halves of the plot.
structure_colours <- function(structure) {
  structures <- sort(unique(structure))
  hues <- grDevices::hcl.colors(length(structures), palette = "Dark 3")
  hues[match(structure, structures)]
}

# HCP suffixes its names "-lh"/"-rh", THOMAS "_L"/"_R".
split_hemi <- function(name) {
  hemi <- ifelse(grepl("(-lh|_L)$", name), "Left", "Right")
  if (!all(grepl("(-lh|-rh|_L|_R)$", name))) {
    cli::cli_abort(
      "No hemisphere suffix on {.val {name[!grepl('(-lh|-rh|_L|_R)$', name)]}}."
    )
  }
  list(hemi = hemi, structure = sub("(-lh|-rh|_L|_R)$", "", name))
}

read_lut <- function(atlas) {
  file <- file.path(
    source_dir,
    sprintf("Thalamus_%s_lookup.csv", toupper(atlas))
  )
  lookup <- utils::read.csv(
    file,
    header = FALSE,
    col.names = c("idx", "name"),
    fileEncoding = "UTF-8-BOM"
  )

  split <- split_hemi(lookup$name)
  label <- paste(split$structure, split$hemi, sep = "_")

  unknown <- setdiff(label_to_region(label), names(region_names[[atlas]]))
  if (length(unknown)) {
    cli::cli_abort("No spelled-out name for {.val {unknown}}.")
  }

  rgb <- grDevices::col2rgb(structure_colours(split$structure))

  data.frame(
    idx = as.integer(lookup$idx) + id_offset,
    label = label,
    R = as.integer(rgb[1, ]),
    G = as.integer(rgb[2, ]),
    B = as.integer(rgb[3, ]),
    A = 0L,
    stringsAsFactors = FALSE
  )
}

# geom_brain() paints rows in order, so the last one lands on top. Sorting by
# nucleus with the two sides adjacent keeps a nucleus at the same depth as its
# contralateral twin, and the grey silhouette leads because it is the
# background the rest sits on and the only geometry present in every view.
draw_order <- function(atlas) {
  drawn <- atlas_geom(atlas)$label
  is_silhouette <- grepl("^cortex", drawn)
  by_structure <- function(x) {
    x[order(
      toupper(sub("_(Left|Right)$", "", x)),
      toupper(x),
      method = "radix"
    )]
  }
  atlas_structure_reorder(
    atlas,
    c(by_structure(drawn[is_silhouette]), by_structure(drawn[!is_silhouette]))
  )
}

build_atlas <- function(atlas) {
  cli::cli_h1("Thalamus {toupper(atlas)}")

  # Wiped rather than reused: contours left over from an earlier slab layout
  # are re-read by the pipeline and land in the atlas with no matching view.
  work_dir <- file.path(data_raw, atlas)
  unlink(work_dir, recursive = TRUE)
  dir.create(work_dir, showWarnings = FALSE, recursive = TRUE)

  lut <- read_lut(atlas)

  src <- file.path(
    source_dir,
    sprintf("Thalamus_%s.nii.gz", toupper(atlas))
  )
  vol <- RNifti::readNifti(src)
  arr <- as.array(vol)
  storage.mode(arr) <- "integer"
  shifted <- array(0L, dim = dim(arr))
  hit <- arr > 0L
  shifted[hit] <- arr[hit] + id_offset

  offset_file <- file.path(work_dir, sprintf("%s_offset.nii.gz", atlas))
  RNifti::writeNifti(RNifti::asNifti(shifted, reference = vol), offset_file)

  merged <- prepare_subcortical_mni152(
    input_volume = offset_file,
    labels = lut$idx,
    lut = lut,
    replace_labels = aseg_thalamus,
    output_file = file.path(work_dir, sprintf("%s_in_aseg.nii.gz", atlas))
  )

  slabs <- subcortical_slabs(
    merged$volume,
    labels = lut$idx,
    coronal = 2,
    axial = 2,
    pad = 2
  )

  raw <- create_subcortical_from_volume(
    input_volume = merged,
    atlas_name = paste0("thalamus_", atlas),
    output_dir = work_dir,
    slabs = slabs,
    skip_existing = FALSE,
    cleanup = FALSE
  )

  # Post-creation, so retuning any of it is seconds rather than a rebuild. The
  # nuclei are grown a little to survive at plotting size; the silhouette is
  # not, since dilating it closes the sulci. Simplify before smoothing, or the
  # dropped vertices put the voxel staircase back.
  #
  # The two are smoothed at different strengths. The nuclei are small, blocky
  # and read as shapes, so they take a heavy pass; the silhouette is a
  # gyrified ribbon whose detail *is* the anatomy, and smoothing it that hard
  # closes the sulci and fills the interior back in.
  out <- raw |>
    aseg_context(
      focus = paste(lut$label, collapse = "|"),
      match_on = "label"
    ) |>
    atlas_view_gather() |>
    atlas_dilate(0.6, exclude = "^cortex") |>
    atlas_simplify(keep = 0.2, labels = "^cortex") |>
    atlas_simplify(keep = 0.35, exclude = "^cortex") |>
    atlas_smooth(smoothness = 0.3, labels = "^cortex") |>
    atlas_smooth(smoothness = 0.9, exclude = "^cortex") |>
    draw_order()

  out <- atlas_core_add(
    out,
    data.frame(
      region = names(region_names[[atlas]]),
      name = unname(region_names[[atlas]]),
      stringsAsFactors = FALSE
    ),
    by = "region"
  )

  cli::cli_alert_success(
    "{length(atlas_labels(out))} nuclei in {length(atlas_views(out))} views"
  )
  out
}

wanted <- commandArgs(trailingOnly = TRUE)
if (length(wanted) == 0) {
  wanted <- c("hcp", "thomas")
}

sysdata_path <- here::here("R", "sysdata.rda")
if (file.exists(sysdata_path)) {
  load(sysdata_path)
}

# Saved after each atlas rather than once at the end, so one that fails does
# not discard the pipeline run before it.
for (atlas in wanted) {
  assign(paste0(".thalamus_", atlas), build_atlas(atlas))

  built <- ls(all.names = TRUE, pattern = "^\\.thalamus_")
  save(list = built, file = sysdata_path, compress = "xz", version = 3)
  cli::cli_alert_success("Saved {length(built)} atlas{?es}")
}
