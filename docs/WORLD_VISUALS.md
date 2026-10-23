# Mundo, superficies e iluminación

La escena utiliza materiales y geometría originales del proyecto. Los vehículos y el piloto mantienen sus activos y sus avisos de licencia existentes. No se añadieron imágenes, texturas ni modelos externos para el entorno.

## Superficies y humedad

`TrackMaterials` crea materiales distintos para asfalto, hormigón, grava, tierra, hierba y arena. El shader usa escalas en metros y reduce el detalle por debajo del tamaño de un píxel. El asfalto tiene árido, variación de desgaste y rugosidad; el hormigón añade juntas; el terreno conserva variación amplia sin modificar su altura o sus colisiones.

`ApexEnvironment.set_wetness()` actualiza los materiales existentes mediante referencias débiles. Los materiales creados después reciben la humedad actual. El agua oscurece el suelo, cambia la rugosidad y crea zonas de agua acumulada en superficies selladas. La luz del cielo y los focos producen el brillo. No se simulan profundidad de charcos ni reflejos exactos de vehículos en pantalla.

Las texturas elegidas por el usuario siguen sustituyendo el color procedural y conservan su proyección. Al cargar una imagen se generan mipmaps para estabilizarla a distancia. La humedad se aplica también a esas superficies. El agarre continúa dependiendo del sistema físico, sin deducirse del brillo del shader.

## Día, noche y garaje

El cielo combina gradiente de altura, nubes estáticas, sol y una variante nocturna. La cobertura aumenta con la humedad. El shader dibuja el fondo directamente para funcionar con Compatibility; no depende de lecturas de `RADIANCE` en el fondo. No utiliza `TIME` ni la posición de cámara para actualizar el cubemap de iluminación.

La iluminación controla exposición, contraste de sombras y niebla de distancia. La niebla afecta poco al cielo para conservar el gradiente y las nubes. Las sombras direccionales se limitan a 180 m. Las farolas iluminan hacia el suelo y se activan cerca del vehículo durante la noche.

`ApexEnvironment.set_quality()` cambia el atlas global mediante `RenderingServer.directional_shadow_atlas_set_size()`: Equilibrado usa 2048 px y dos cascadas; Alto usa 4096 px y cuatro. Ambos conservan profundidad de 32 bits para evitar perder precisión. El bias se adapta al tamaño del atlas para evitar bandas de autosombra; Equilibrado ofrece sombras de contacto menos precisas. El cambio es inmediato y no altera la física.

El garaje tiene suelo de juntas discretas, plataforma circular suavizada, borde rojo, fondo APEX y tres focos de estudio. El fondo y las luces se ajustan por separado de las condiciones de carrera.

## Vegetación y señales

El bosque mezcla dos variantes de árboles de hoja ancha y dos de coníferas. Semilla, escala, orientación y posición varían de forma reproducible. Las copas tienen varios grupos de ramas y un movimiento suave. Los troncos conservan cuerpos de colisión. La hierba junto a la escapatoria es decorativa; el suelo sigue resolviendo los contactos.

Las señales de 150, 100 y 50 m anticipan curvas de suficiente magnitud. Se sitúan fuera de la vía y no cambian la trazada de la IA. Sus postes, las farolas y los troncos son obstáculos sólidos.

## Presupuesto y límites

| Elemento | Límite de construcción o visibilidad |
|---|---|
| Árboles | Hasta 340 posiciones antes del rechazo por terreno; cuatro mallas compartidas |
| Hierba | Hasta 1300 grupos de nueve hojas antes del rechazo por terreno |
| Farolas | Hasta 120; espaciado mínimo de 90 m |
| Vegetación | `MultiMesh` en celdas de 160 m; árboles hasta 460 m y hierba hasta 210 m desde el centro del grupo |
| Sombras | Dirección del sol hasta 180 m; la hierba y las farolas no añaden sombras dinámicas propias |
| Luces de pista | Solo durante la noche y a menos de 100 m del vehículo |

Estos límites acotan el trabajo; no constituyen una garantía de FPS para cualquier equipo. El entorno conserva una apariencia estilizada de geometría procedural. No incorpora fotogrametría, vegetación escaneada, iluminación global dinámica ni reflexión de pantalla, para mantener una ruta común de renderizado de escritorio y Web con Compatibility.

## Comprobación visual reproducible

Ejecutar desde la raíz del proyecto:

```bash
godot --path . --rendering-method gl_compatibility --script tools/world_visual_probe.gd -- --output=/ruta/a/capturas
```

El probe crea la misma cámara, vehículo y posición en Costa y escribe `day-dry.png`, `day-wet.png`, `night-wet.png` y `showroom.png`. Permite comparar una modificación con la versión anterior sin que cambien el encuadre ni la conducción. Es una captura de validación visual, no una prueba de rendimiento. Para validar física se usan las pruebas de colisiones y circuitos existentes.

Se completaron las cuatro capturas con Godot 4.6.3, Compatibility y Mesa llvmpipe bajo Xvfb; el proceso terminó con `WORLD_VISUAL_PROBE PASS` sin errores de shader o de script. La comparación detectó y corrigió cielo negro al leer el cubemap y bandas de autosombra por un bias insuficiente. La versión final se capturó con Equilibrado; también se comprobó la configuración de cuatro cascadas. La carretera nocturna se orienta mediante faros, farolas y bordes; los objetos fuera de esas luces permanecen oscuros.

El registro imprime los contadores de objetos, primitivas y llamadas de dibujo que informa Godot. En esta escena con una Yamaha, el garaje ya informa unas 574000 primitivas y 338 llamadas; Costa diurna unas 948000 y 551. Son contadores de un encuadre y un equipo de validación, no FPS medidos ni un límite para el juego. Los modelos detallados y varias pasadas de sombra siguen suponiendo un coste considerable, especialmente con renderizado por CPU.

## Referencias del motor

- [Shader de cielo y actualización del cubemap, Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/sky_shader.html)
- [Materiales y variables de shaders espaciales, Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html)
- [Entorno, contribución ambiental y niebla, Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_environment.html)
- [Atlas de sombra direccional, Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#class-renderingserver-method-directional-shadow-atlas-set-size)
