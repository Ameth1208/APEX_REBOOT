# Interfaz de conducción

## Cambios visibles

- Inicio: una sola navegación superior. Conducir muestra la configuración de sesión; Garaje muestra vehículos y apariencia. No se reconstruyen los campos al cambiar de sección, y el vehículo seleccionado se conserva.

- Pausa: lista lateral sobre la escena detenida, con foco inicial en Continuar.
- Reiniciar y Volver al garaje solicitan confirmación.
- Cambiar cámara vuelve a conducir usando la siguiente cámara existente.
- Modo foto activa la cámara libre existente; se cierra con la acción de foto o Escape.
- Ajustes: navegación lateral por Controles, Gráficos, Audio, Conducción, HUD y Accesibilidad.
- Gráficos y Conducción ocultan sus parámetros detallados bajo un botón de opciones avanzadas.
- Accesibilidad expone los controles existentes de movimiento de cámara, inclinación y campo de visión.
- HUD: preferencias persistentes para minimapa, clasificación, tiempos y tamaño del velocímetro.
- Instrumentos: fondo translúcido, marcha grande, velocidad digital, RPM reales y pedales.
- Resultados: posición destacada, tiempos y clasificación completa desplegable.

Abrir Ajustes desde pausa y pulsar Volver conserva la pausa. Las preferencias se guardan mediante el sistema existente.

## Comprobación visual

Ejecutar desde la raíz:

    godot_console --path . --script res://tools/ui_preview.gd

Genera capturas de los componentes reales de ajustes, pausa, resultados e instrumentos a 960×540, 1280×720, 1920×1080 y 2560×1080 en `user://qa/ui`. Esta herramienta usa valores temporales y no guarda preferencias.

La prueba de integración existente se ejecuta con:

    godot_console --headless --path . -- --qa

## Alcance pendiente

La revisión visual y las pruebas automáticas no certifican el comportamiento de un mando físico. Accesibilidad todavía no incorpora escalado global de texto o paletas alternativas. El rediseño integral del creador (pinceles de terreno y vegetación, edición 3D y retorno desde prueba con restauración de estado) sigue siendo trabajo pendiente; estas pantallas no lo implementan.
