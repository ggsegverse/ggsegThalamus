#' Thalamic Nuclei Atlases
#'
#' Two published parcellations of the thalamus, from different modalities and
#' at different granularities. Each is drawn in four views, two coronal and
#' two axial, with the surrounding brain in grey for anatomical context — the
#' other deep grey structures included, since these atlases subdivide the
#' thalamus alone. Both contain 2D polygon geometry for
#' [ggseg::geom_brain()] and 3D mesh data for [ggseg3d::ggseg3d()].
#'
#' Labels keep the identifiers the published lookup tables use, and `region`
#' is those stripped of the hemisphere suffix and lower-cased, so both are
#' easy to match on. The `name` column carries the spelled-out nucleus name
#' for printing to a reader.
#'
#' For the FreeSurfer thalamic segmentation see `ggsegFreeSurfer::thalamus()`,
#' which is a different atlas again.
#'
#' @family ggseg_atlases
#' @family subcortical_atlases
#' @name thalamus
#'
#' @return A [ggseg.formats::ggseg_atlas] object (subcortical).
#' @examples
#' thalamus_hcp()
#' plot(thalamus_hcp())
NULL


#' @describeIn thalamus Seven nuclei groups per hemisphere, clustered from
#'   Human Connectome Project diffusion MRI.
#'
#' @references Najdenovska E, Aleman-Gomez Y, Battistella G, et al. (2018).
#'   In-vivo probabilistic atlas of human thalamic nuclei based on
#'   diffusion-weighted magnetic resonance imaging. *Scientific Data*, 5,
#'   180270. (\doi{10.1038/sdata.2018.270})
#' @export
thalamus_hcp <- function() .thalamus_hcp


#' @describeIn thalamus Twelve nuclei per hemisphere, segmented from
#'   white-matter-nulled MPRAGE by the THOMAS pipeline. Finer than the
#'   diffusion-based grouping, and the only one of the two to separate the
#'   geniculate nuclei, the habenula and the mammillothalamic tract.
#'
#' @references Su JH, Thomas FT, Kasoff WS, et al. (2019). Thalamus Optimized
#'   Multi Atlas Segmentation (THOMAS): fast, fully automated segmentation of
#'   thalamic nuclei from structural MRI. *NeuroImage*, 194, 272-282.
#'   (\doi{10.1016/j.neuroimage.2019.03.021})
#' @export
thalamus_thomas <- function() .thalamus_thomas
