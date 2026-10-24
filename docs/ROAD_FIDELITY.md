# Garaje, apoyo del vehículo y carretera real

## Correcciones

- El fondo opaco de CanvasLayer ocultaba el modelo 3D del garaje. Se desactiva en la pantalla principal.
- La tarjeta activa muestra «Seleccionado» y la identidad identifica el vehículo elegido.
- El material físico de una carretera tiene prioridad sobre las zonas OSM de uso del suelo. Antes una parcela de hierba podía sustituir el asfalto al consultar el contacto.
- El modo fiel no eleva cruces automáticamente para fabricar puentes.
- Los arcenes se construyen también en partes altas de rutas fieles, evitando huecos por el umbral global de altura.
- La división del terreno en chunks conserva los colores por vértice que representan las superficies detectadas.

## Polonuevo–Baranoa

Se consultaron los 214 controles de la carretera existente en Open-Meteo el 24 de octubre de 2026. El perfil DEM queda guardado en `data/tracks/polonuevo_baranoa_elevation.json` y se aplica al cargar la ruta desde el catálogo, sin modificar X/Z ni las observaciones originales de `raw_route`. Un hash de la fuente y el número de controles impiden aplicar el perfil a otra ruta.

Fuente: Open-Meteo / Copernicus DEM GLO-90, resolución aproximada 90 m.
Documentación y atribución: https://open-meteo.com/en/docs/elevation-api
Copernicus DEM: https://doi.org/10.5270/ESA-c5d3d65

Esto reemplaza la prueba plana por un perfil de terreno estimado. No es un levantamiento de la calzada: faltan cotas detalladas, información fiable de puentes/túneles y confirmación de materiales por tramo. Las imágenes satelitales no proporcionan alturas por sí mismas.

Se añadió una cuadrícula de 28×19 muestras de terreno independientes de la calzada (532 alturas), con separación de 240 m, guardada en `polonuevo_baranoa_terrain.json`. La malla usa interpolación bilineal de esa cuadrícula con el mismo origen vertical de la carretera. La resolución de la fuente DEM sigue siendo 90 m; la malla consultada a 240 m no equivale a un levantamiento de 90 m. Fuera de su cobertura se conserva el terreno aproximado anterior.

Las carreteras geográficas fieles no generan pianos, pilares de viaducto, pórticos de competición, bosques, farolas ni señales de circuito inventados. El entorno cartográfico sigue construyéndose cuando existen datos. Edificios y agua se ubican respecto a la altura del terreno generado, no respecto a una cota global cero. La altura de agua sigue siendo una aproximación, no una medición hidrológica.

La consulta de superficies por carretera no se completó: Overpass principal respondió HTTP 406 y el proveedor alternativo agotó el tiempo de espera. Polonuevo muestra «Superficie sin confirmar»; no se declara detección de asfalto/tierra que no se haya obtenido.

## Física

La gravedad del proyecto es 9,81 m/s². La prueba de caída libre verifica un vehículo sin aerodinámica ni apoyo. El perfil actual del Corolla declara cero carga aerodinámica; multiplicar ese valor en Ajustes no añade un alerón. La prueba de Formula verifica carga aerodinámica positiva, contacto de las cuatro ruedas y compresión de suspensión a alta velocidad.

Comprobaciones:

    godot_console --headless --path . --fixed-fps 120 --script tests/physics_checks.gd
    godot_console --headless --path . --fixed-fps 120 --script tests/formula_handling_checks.gd
    godot_console --headless --path . --script tests/road_fidelity_checks.gd
