<?php

namespace Tests\Unit;

use App\Support\GeoIstmo;
use Tests\TestCase;

class GeoIstmoTest extends TestCase
{
    public function test_reconoce_un_punto_dentro_del_istmo(): void
    {
        // Juchitán de Zaragoza, dentro de la caja del Istmo.
        $this->assertTrue(GeoIstmo::dentroDelIstmo(16.4331, -95.0208));
    }

    public function test_rechaza_un_punto_fuera_del_istmo(): void
    {
        // Ciudad de México, muy lejos del Istmo.
        $this->assertFalse(GeoIstmo::dentroDelIstmo(19.4326, -99.1332));
    }

    public function test_distancia_a_polilinea_es_cero_sobre_la_linea(): void
    {
        $linea = [
            ['lat' => 16.40, 'lng' => -95.00],
            ['lat' => 16.50, 'lng' => -95.00],
        ];
        $punto = ['lat' => 16.45, 'lng' => -95.00];

        $this->assertLessThan(1.0, GeoIstmo::distanciaAPolilinea($punto, $linea));
    }

    public function test_distancia_a_polilinea_mide_metros_de_separacion(): void
    {
        // El punto está ~1 grado de longitud al oeste (~106 km a esa latitud).
        $linea = [
            ['lat' => 16.40, 'lng' => -95.00],
            ['lat' => 16.50, 'lng' => -95.00],
        ];
        $punto = ['lat' => 16.45, 'lng' => -95.01]; // ~1 km al oeste

        $dist = GeoIstmo::distanciaAPolilinea($punto, $linea);
        $this->assertGreaterThan(900, $dist);
        $this->assertLessThan(1200, $dist);
    }

    public function test_desvio_perpendicular_se_aleja_del_bloqueo(): void
    {
        $linea = [
            ['lat' => 16.40, 'lng' => -95.00],
            ['lat' => 16.50, 'lng' => -95.00], // ruta que va hacia el norte
        ];
        $bloqueo = ['lat' => 16.45, 'lng' => -95.00];

        $wp = GeoIstmo::desvioPerpendicular($bloqueo, $linea, 2500.0);

        // Ruta norte-sur -> el desvío debe moverse en longitud (este/oeste),
        // no en latitud, y a ~2.5 km del bloqueo.
        $sep = GeoIstmo::distanciaAPolilinea($wp, [$bloqueo, $bloqueo]);
        $this->assertGreaterThan(2000, $sep);
        $this->assertLessThan(3000, $sep);
    }
}
