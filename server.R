# SERVER.R
function(input, output, session) {
  
  RI <- rast("data/_RI/LRScore.tif")
  
  # Layer cache (for lazy loading)
  base_group_cache <- list(
    (`Landscape Resilience` = c(TRUE, RI, RI_pal, RI_lpal, "Score")),
    (`Critical Habitat` = c(FALSE, ch_map, ch_pal, ch_lpal, "Total Ha")), 
    (`SAR Richness` = c(FALSE, sar_rich_map, sar_rich_pal, sar_rich_lpal, "Count")),
    (`END Richness` = c(FALSE, end_rich_map, end_rich_pal, end_rich_lpal, "Count")), 
    (`Common Richness` = c(FALSE, biod_rich_map, biod_rich_pal, biod_rich_lpal, "Count")),
    (`SAR Goal` = c(FALSE, sar_goal_map, sar_goal_pal, sar_goal_lpal, "% Goal Scaled")), 
    (`END Goal` = c(FALSE, end_goal_map, end_goal_pal, end_goal_lpal, "% Goal Scaled")),
    (`Common Goal` = c(FALSE, biod_goal_map, biod_goal_pal, biod_goal_lpal, "% Goal Scaled")),
    (`Connectivity` = c(FALSE, connect_map, connect_pal, connect_lpal, "Current Density")),    
    (`Climate Refugia` = c(FALSE, climate_r_map, climate_r_pal, climate_r_lpal, "Index")),
    (`Climate Centrality` = c(FALSE, climate_c_map, climate_c_pal, climate_c_lpal, "KM per year")),
    (`Forest` = c(FALSE, forest_map, forest_pal, forest_lpal, "Ha")),
    (`Grassland` = c(FALSE, grass_map, grass_pal, grass_lpal, "Ha")),
    (`Wetland` = c(FALSE, wet_map, wet_pal, wet_lpal, "Ha")),
    (`Rivers` = c(FALSE, river_map, river_pal, river_lpal, "Km")),
    (`Human Footprint Index` = c(FALSE, hfi_map, hfi_pal, hfi_lpal, 'Index')),
    (`Climate Extremes` = c(FALSE, climate_e_map, climate_e_pal, climate_e_lpal, "Index")),
    (`Off` = TRUE)
  )
  
  ## update names
  names(base_group_cache) <- c(
    "Landscape Resilience", 
    "Critical Habitat", 
    "SAR Richness", "END Richness", "Common Richness",
    "SAR Goal", "END Goal", "Common Goal",
    "Connectivity", 
    "Climate Refugia", "Climate Centrality",
    "Forest", "Grassland", "Wetland", "Rivers",
    "Human Footprint", "Climate Extremes", 
    "Off"
  )  
  
  # Make weights df reactive
  weights_tbl <- reactiveVal(weights_tbl)
  
  ## Init map
  output$RI_MAP <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      addGlPoints(data = pts_wgs,
                  radius = 5,
                  group = "LR Scores",
                  layerId = "RI_Points",
                  popup = paste0("<b>LR Score: </b>", pts_wgs$RI),
                  color = "#2b8cbe") %>%
      hideGroup("LR Scores") %>%
      ## ri
      addRasterImage(
        raster(RI), 
        colors = RI_pal,
        layerId = "RI",
        group = "Landscape Resilience") %>%
      addLegend(pal=RI_lpal, 
                values=values(raster(RI)), 
                position="bottomleft", 
                opacity=1,
                title="Score",
                layerId="ri-legend",
                labFormat=labelFormat(transform = function(x) sort(x, decreasing = TRUE))) %>%
      ## kba
      addRasterImage(
        raster(kba),
        colors = c('#00000000','#ef3b2c'),
        group = "KBA") %>%
      hideGroup("KBA") %>%
      ## protected
      addRasterImage(
        raster(pa_map),
        colors = pa_pal,
        method = "ngb",
        group = "Protected") %>%
      hideGroup("Protected") %>%
      ## layer controls
      addLayersControl(
        overlayGroups = c("Protected", "KBA", "LR Scores"),
        baseGroups = c(
          "Landscape Resilience", 
          "Critical Habitat", 
          "SAR Richness", "END Richness", "Common Richness",
          "SAR Goal", "END Goal", "Common Goal",
          "Connectivity",
          "Climate Refugia", "Climate Centrality",
          "Forest", "Grassland", "Wetland", "Rivers",
          "Human Footprint", "Climate Extremes", 
          "Off"          
          ),
        options = layersControlOptions(collapsed = FALSE)) %>%
      htmlwidgets::onRender("
      function(el, x) {
        var myMap = this;
        myMap.on('baselayerchange',
          function (e) {
            Shiny.onInputChange('RI_MAP_tile', e.layer.groupname)
        })
    }")
  })
  
  # Update map (lazy load base group features)
  observeEvent(input$RI_MAP_tile, {
    
    ## add map spinner
    shinyjs::runjs(
     "const spinner = document.querySelector('.spinner');
     spinner.style.display = 'block'")
    
    ## remove legend if off
    if (input$RI_MAP_tile == "Off") {
      leafletProxy("RI_MAP") %>%
        removeControl("ri-legend")
    } else {
      ## add legend based on layer
      leafletProxy("RI_MAP") %>%
        removeControl("ri-legend") %>%
        addLegend(pal=base_group_cache[[input$RI_MAP_tile]][4][[1]], 
                  values=values(raster(base_group_cache[[input$RI_MAP_tile]][2][[1]])), 
                  position="bottomleft",
                  opacity=1,
                  title=base_group_cache[[input$RI_MAP_tile]][5][[1]], 
                  layerId="ri-legend",
                  labFormat=labelFormat(transform = function(x) sort(x, decreasing = TRUE),
                                        digits = 7, big.mark = ','))
    }
    
    ## lazy load
    if (!base_group_cache[[input$RI_MAP_tile]][1][[1]]) {
      ## update variable to TRUE
      base_group_cache[[input$RI_MAP_tile]][1][[1]] <<- TRUE
      ## update map
      leafletProxy("RI_MAP") %>%
      addRasterImage(
           raster(base_group_cache[[input$RI_MAP_tile]][2][[1]]),
           colors = base_group_cache[[input$RI_MAP_tile]][3][[1]],
           group = input$RI_MAP_tile) %>%
         showGroup(input$RI_MAP_tile)
    }
    
    ## remove spinner
    shinyjs::runjs(
      "const spinner = document.querySelector('.spinner');
      spinner.style.display = 'none'")  
  })
  
  # Reset RI to CP&P recommendation 
  observeEvent(input$ri_reset, {
    updateNumericInput(session, "kba", value = 1)
    updateNumericInput(session, "ch", value = 1)
    updateNumericInput(session, "sar_rich", value = 1)
    updateNumericInput(session, "end_rich", value = 1)
    updateNumericInput(session, "biod_rich", value = 1)
    updateNumericInput(session, "sar_goal", value = 1)
    updateNumericInput(session, "end_goal", value = 1)
    updateNumericInput(session, "biod_goal", value = 1)
    updateNumericInput(session, "climate_e", value = 1)
    updateNumericInput(session, "climate_r", value = 1)
    updateNumericInput(session, "climate_c", value = 1)
    updateNumericInput(session, "connect", value = 1)
    updateNumericInput(session, "forest", value = 1)
    updateNumericInput(session, "grass", value = 1)
    updateNumericInput(session, "wet", value = 1)
    updateNumericInput(session, "river", value = 1)
    updateNumericInput(session, "shore", value = 1)
    updateNumericInput(session, "pa", value = 1)
    updateNumericInput(session, "hfi", value = 1)
  })
  
  # Update RI: RI equation
  observeEvent(input$ri_update, {
    
    ## add map spinner
    shinyjs::runjs(
      "const spinner = document.querySelector('.spinner');
     spinner.style.display = 'block'")
    
  ## update weights table
  weight_values <- c(
    input$kba, input$ch, 
    input$sar_rich, input$end_rich, input$biod_rich,
    input$sar_goal, input$end_goal, input$biod_goal,
    input$climate_e, input$climate_r, input$climate_c,
    input$connect, 
    input$forest, input$grass, input$wet, input$river, input$shore,
    input$pa, input$hfi)
   weights_tbl(weights_tbl() %>% mutate(VALUES = weight_values))
  
  ## build RI  
  RI <<- (
     (kba * input$kba) # + key biodiversity
    + (ch * input$ch)  # + critical habitat
    + (sar_rich * input$sar_rich)  # + SAR species richness 
    + (end_rich * input$end_rich)  # + END species richness 
    + (biod_rich * input$biod_rich)  # + Common species richness 
    + (sar_goal * input$sar_goal)  # + SAR species goal 
    + (end_goal * input$end_goal)  # + END species goal 
    + (biod_goal * input$biod_goal)  # + common species goal 
    + (climate_r * input$climate_r)  # + climate refugia
    + (climate_c * input$climate_c)  # + climate centrality
    + (connect * input$connect)  # + connectivity
    + (forest * input$forest) # + forest land cover
    + (grass * input$grass) # + grassland
    + (wet * input$wet) # + wetland
    + (river * input$river) # + river
    + (pa * input$pa) # + protected areas
    - (hfi * input$hfi)  # - human footprint index
    - (climate_e * input$climate_e)  # - climate extremes
  )
  ## scale RI
  RI <<- normalize_between_0_and_1(RI)
  
  ## update map
  leafletProxy("RI_MAP") %>%
    removeImage("RI") %>%
    addRasterImage(
      raster(RI), 
      colors = RI_pal,
      group = "Landscape Resilience")
  
  ## extract points
  ri_df <- exactextractr::exact_extract(RI, pts_buf, "mean", force_df = TRUE) %>%
    rename("RI" = mean) %>%
    mutate(ID = row_number()) %>%
    mutate(RI = round(RI, 4))
  
  ## replace value
  pts_wgs['RI'] <- ri_df['RI']
  
  ## update points
  leafletProxy("RI_MAP") %>%
   clearGlLayers() %>%
    addGlPoints(data = pts_wgs,
                radius = 5,
                group = "LR Scores",
                layerId = "RI_Points",
                popup = paste0("<b>LR Score: </b>", pts_wgs$RI),
                color = "#2b8cbe") %>%
    hideGroup("LR Scors") %>% # <--- hack to remove points??
    showGroup("LR Scores") %>% # <--- hack to remove points??
    hideGroup("LR Scores") # <--- hack to remove points??
   
  ## remove spinner
  shinyjs::runjs(
    "const spinner = document.querySelector('.spinner');
      spinner.style.display = 'none'")    
  
 })
  
  # Equation text for download
  RI_equ <- reactive({ as.character(
    paste0(
      "(key biodiversity areas * ", input$kba, ")",
      " + (critical habitat * ",  input$ch, ")",
      " + (SAR richness * ", input$sar_rich, ")",
      " + (END richness * ", input$end_rich, ")",
      " + (Common richness * ", input$biod_rich, ")",
      " + (SAR goal * ", input$sar_goal, ")",
      " + (END goal * ", input$end_goal, ")",
      " + (common goal * ", input$biod_goal, ")",
      " + (climate refugia * ", input$climate_r, ")",
      " + (climate centrality * ", input$climate_c, ")",
      " + (connectivity * ", input$connect, ")",
      " + (forest * ", input$forest, ")",
      " + (grassland * ", input$grass, ")",
      " + (wetland * ", input$wet, ")",
      " + (rivers * ", input$river, ")",
      " + (shoreline * ", input$shore, ")",
      " + (existing conservation * ", input$pa, ")",
      " - (human footprint index * ", input$hfi, ")",
      " - (climate extremes * ", input$climate_e, ")"
    )) 
  })

  # RI positive weight tally
  output$pos_weights <-  renderText({
    ## list of positive weights
    positive_weight_tally <- (
      input$kba + input$ch +
      input$sar_rich + input$end_rich + input$biod_rich +
      input$sar_goal + input$end_goal + input$biod_goal +
      input$climate_r + input$climate_c + 
      input$connect + 
      input$forest + input$grass + input$wet + input$river + input$shore +
      input$pa
    ) 
    ## translate to HTML
    HTML(paste0("<b> Positive Weight tally:</b> ", positive_weight_tally))
  })
  
  # RI negative weight tally
  output$neg_weights <-  renderText({ 
    ## list of negative weights
    negative_weight_tally <- input$hfi + input$climate_e
    ## translate to HTML
    HTML(paste0("<b>Negative Weight tally:</b> ", negative_weight_tally))
  })    
  
  # RI equation for display
  output$equation <-  renderText({
    ## positive weights
    positive_ri_inputs <- list(
      list("feature" = "KBA", "weight" = input$kba, "class" = "var-bio"),
      list("feature" = "critical habitat", "weight" = input$ch, "class" = "var-bio"),
      list("feature" = "SAR richness", "weight" = input$sar_rich, "class" = "var-bio"),
      list("feature" = "END richness", "weight" = input$end_rich, "class" = "var-bio"),
      list("feature" = "common richness", "weight" = input$biod_rich, "class" = "var-bio"),
      list("feature" = "SAR goal", "weight" = input$sar_goal, "class" = "var-bio"),
      list("feature" = "END goal", "weight" = input$end_goal, "class" = "var-bio"),
      list("feature" = "common goal", "weight" = input$biod_goal, "class" = "var-bio"),
      list("feature" = "climate refugia", "weight" = input$climate_r, "class" = "var-climate"),
      list("feature" = "climate centrality", "weight" = input$climate_c, "class" = "var-climate"),
      list("feature" = "connectivity", "weight" = input$connect, "class" = "var-connect"),
      list("feature" = "forest", "weight" = input$forest, "class" = "var-habitat"),
      list("feature" = "grassland", "weight" = input$grass, "class" = "var-habitat"),
      list("feature" = "wetland", "weight" = input$wet, "class" = "var-habitat"),
      list("feature" = "rivers", "weight" = input$river, "class" = "var-habitat"),
      list("feature" = "shoreline", "weight" = input$shore, "class" = "var-habitat"),
      list("feature" = "existing conservation", "weight" = input$pa, "class" = "var-protection")
      )
    
    ## negative weights
    negative_ri_inputs <- list(
      list("feature" = "human footprint", "weight" = input$hfi, "class" = "var-threat"),
      list("feature" = "climate extremes", "weight" = input$climate_e, "class" = "var-threat")
    )  
    
    ## sort by weight
    sorted_p <- positive_ri_inputs[order(-sapply(positive_ri_inputs, function(x) x$weight))]
    sorted_n <- negative_ri_inputs[order(-sapply(negative_ri_inputs, function(x) x$weight))]
    
    ## translate to HTML
    HTML(paste0(
      "(<p class=", sorted_p[[1]]$class, ">", sorted_p[[1]]$feature, "</p> * <span>", sorted_p[[1]]$weight, "</span>)",
      " + (<p class=", sorted_p[[2]]$class, ">", sorted_p[[2]]$feature, "</p> * <span>", sorted_p[[2]]$weight, "</span>)",
      " + (<p class=", sorted_p[[3]]$class, ">", sorted_p[[3]]$feature, "</p> * <span>", sorted_p[[3]]$weight, "</span>)",
      " + (<p class=", sorted_p[[4]]$class, ">", sorted_p[[4]]$feature, "</p> * <span>", sorted_p[[4]]$weight, "</span>)",
      " + (<p class=", sorted_p[[5]]$class, ">", sorted_p[[5]]$feature, "</p> * <span>", sorted_p[[5]]$weight, "</span>)",
      " + (<p class=", sorted_p[[6]]$class, ">", sorted_p[[6]]$feature, "</p> * <span>", sorted_p[[6]]$weight, "</span>)",
      " + (<p class=", sorted_p[[7]]$class, ">", sorted_p[[7]]$feature, "</p> * <span>", sorted_p[[7]]$weight, "</span>)",
      " + (<p class=", sorted_p[[8]]$class, ">", sorted_p[[8]]$feature, "</p> * <span>", sorted_p[[8]]$weight, "</span>)",
      " + (<p class=", sorted_p[[9]]$class, ">", sorted_p[[9]]$feature, "</p> * <span>", sorted_p[[9]]$weight, "</span>)",
      " + (<p class=", sorted_p[[10]]$class, ">", sorted_p[[10]]$feature, "</p> * <span>", sorted_p[[10]]$weight, "</span>)",
      " + (<p class=", sorted_p[[11]]$class, ">", sorted_p[[11]]$feature, "</p> * <span>", sorted_p[[11]]$weight, "</span>)",
      " + (<p class=", sorted_p[[12]]$class, ">", sorted_p[[12]]$feature, "</p> * <span>", sorted_p[[12]]$weight, "</span>)",
      " + (<p class=", sorted_p[[13]]$class, ">", sorted_p[[13]]$feature, "</p> * <span>", sorted_p[[13]]$weight, "</span>)",
      " + (<p class=", sorted_p[[14]]$class, ">", sorted_p[[14]]$feature, "</p> * <span>", sorted_p[[14]]$weight, "</span>)",
      " + (<p class=", sorted_p[[15]]$class, ">", sorted_p[[15]]$feature, "</p> * <span>", sorted_p[[15]]$weight, "</span>)",
      " + (<p class=", sorted_p[[16]]$class, ">", sorted_p[[16]]$feature, "</p> * <span>", sorted_p[[16]]$weight, "</span>)",
      " + (<p class=", sorted_p[[17]]$class, ">", sorted_p[[17]]$feature, "</p> * <span>", sorted_p[[17]]$weight, "</span>)",
      " - (<p class=", sorted_n[[1]]$class, ">", sorted_n[[1]]$feature, "</p> * <span>", sorted_n[[1]]$weight, "</span>)",
      " - (<p class=", sorted_n[[2]]$class, ">", sorted_n[[2]]$feature, "</p> * <span>", sorted_n[[2]]$weight, "</span>)"
    ))
  })
  
  # Download RI
  observe(
    download_SERVER(id = "download_mod1", RI = RI, weights_tbl = weights_tbl)
  )
    
  # Info modal
  toggleModal(session, modalId="info-modal", toggle="close")
  
  # Tool tips
  ## RI reset button
  addTooltip(session, id = "ri_reset", title = "Reset values back to CP&P Recommendation",
             placement = "top", trigger = "hover")
  ## RI update button
  addTooltip(session, id = "ri_update", title = "Update scores using new values",
             placement = "top", trigger = "hover")
  ## info button
  addTooltip(session, id = "info", title = "View PowerPoint",
             placement = "bottom", trigger = "hover")  

# CLOSE SERVER    
}
