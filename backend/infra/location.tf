# Amazon Location Service: mapa base, geocodificación y cálculo de rutas.

resource "aws_location_map" "mapa" {
  map_name = "${local.prefix}-mapa"

  configuration {
    style = "VectorEsriStreets"
  }
}

resource "aws_location_place_index" "lugares" {
  index_name  = "${local.prefix}-lugares"
  data_source = "Esri"

  data_source_configuration {
    intended_use = "SingleUse"
  }
}

resource "aws_location_route_calculator" "rutas" {
  calculator_name = "${local.prefix}-rutas"
  data_source     = "Esri"
}
