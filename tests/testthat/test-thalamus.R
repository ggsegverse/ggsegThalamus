atlases <- list(
  thalamus_hcp = list(atlas = thalamus_hcp, per_hemi = 7L),
  thalamus_thomas = list(atlas = thalamus_thomas, per_hemi = 12L)
)

for (nm in names(atlases)) {
  local({
    spec <- atlases[[nm]]
    name <- nm

    describe(paste0(name, "()"), {
      it("is a subcortical ggseg_atlas", {
        expect_s3_class(spec$atlas(), "ggseg_atlas")
        expect_s3_class(spec$atlas(), "subcortical_atlas")
        expect_true(ggseg.formats::is_ggseg_atlas(spec$atlas()))
      })

      it("has the published number of nuclei per hemisphere", {
        core <- spec$atlas()$core
        expect_identical(nrow(core), spec$per_hemi * 2L)
        expect_identical(
          as.integer(table(core$hemi)[c("left", "right")]),
          rep(spec$per_hemi, 2L)
        )
      })

      it("derives region as a plain strip of the label", {
        core <- spec$atlas()$core
        stripped <- sub("_(Left|Right)$", "", core$label)
        stripped <- gsub("[-_/]", " ", stripped)
        stripped <- gsub("\\s+", " ", trimws(tolower(stripped)))
        expect_identical(core$region, stripped)
      })

      it("carries a spelled-out name for every region", {
        core <- spec$atlas()$core
        expect_true("name" %in% names(core))
        expect_false(anyNA(core$name))
      })

      it("gives both hemispheres of a nucleus the same name and colour", {
        core <- spec$atlas()$core
        pal <- ggseg.formats::atlas_palette(spec$atlas())
        per_region <- tapply(core$name, core$region, function(x) {
          length(unique(x))
        })
        expect_true(all(per_region == 1))
        structure <- sub("_(Left|Right)$", "", names(pal))
        per_structure <- tapply(unname(pal), structure, function(x) {
          length(unique(x))
        })
        expect_true(all(per_structure == 1))
      })

      it("has 2D polygon geometry in four views", {
        expect_true(ggseg.formats::is_atlas_polygon(spec$atlas()))
        expect_length(ggseg.formats::atlas_views(spec$atlas()), 4)
      })

      it("has 3D meshes for every label", {
        meshes <- ggseg.formats::atlas_meshes(spec$atlas())
        expect_setequal(meshes$label, spec$atlas()$core$label)
      })
    })
  })
}

describe("thalamus_thomas()", {
  it("separates the nuclei the diffusion grouping cannot", {
    regions <- unique(thalamus_thomas()$core$region)
    expect_true(all(c("lgn", "mgn", "hb", "mtt") %in% regions))
  })

  it("renders with ggseg", {
    skip_if_not_installed("ggseg")
    expect_doppelganger(
      "thalamus_thomas-2d",
      ggseg::brain_test_plot(thalamus_thomas())
    )
  })
})

describe("thalamus_hcp()", {
  it("renders with ggseg", {
    skip_if_not_installed("ggseg")
    expect_doppelganger(
      "thalamus_hcp-2d",
      ggseg::brain_test_plot(thalamus_hcp())
    )
  })
})
