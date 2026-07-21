// Estilo del mapa: tiles raster de OpenStreetMap (el look de las screenshots).
// Sin llaves ni AWS: el navegador pide los tiles directo a OSM.
export async function resolverEstiloMapa() {
  return {
    style: {
      version: 8 as const,
      sources: {
        osm: {
          type: 'raster' as const,
          tiles: [
            'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png',
          ],
          tileSize: 256,
          attribution: '© OpenStreetMap',
        },
      },
      layers: [{ id: 'osm', type: 'raster' as const, source: 'osm' }],
    },
    opciones: {},
    esDemo: false,
  }
}
