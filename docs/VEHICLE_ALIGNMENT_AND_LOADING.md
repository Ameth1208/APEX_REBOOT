# Carrocería, ruedas y carga de vehículos

## Corrección de alineación

Los perfiles nuevos activaban `align_wheels_to_physics`, pero el rig movía las
ruedas sin trasladar la carrocería. La auditoría midió desplazamientos
longitudinales de aproximadamente 24 cm en el Golf, 20 cm en el Cupra, 18 cm en
el Picanto y 35 cm en el Elantra.

`VehicleVisual` ahora mide ambos ejes importados y ajusta primero la posición
y escala longitudinal de todo el modelo. Después separa las ruedas animadas.
Los pasos de rueda permanecen sobre los ejes físicos. No cambia fuerzas,
agarre, masa, suspensión ni archivos GLB/FBX originales. La escala longitudinal
se limita a 0,8–1,2; importaciones fuera de ese margen requieren revisión.
El ancho todavía se calibra mediante los contactos del perfil: no es un
reescaneo ni una reconstrucción exacta de cada carrocería.

## Rendimiento y carga

- Exportar todos los recursos al paquete no implica instanciar todos los coches.
  El menú instancia el vehículo seleccionado y una carrera usa ese perfil para
  el jugador y los rivales.
- `VehicleModelLoader` conserva como máximo dos recursos de modelo. Evita
  volver a leer el PackedScene al crear cada rival, sin precargar el catálogo.
- `VehicleBodyBatcher` agrupa piezas pequeñas, rígidas y opacas por material,
  formato, sombras y capa. Ruedas, cristales, mallas con esqueleto y paneles
  densos quedan separados. Conserva materiales editables y genera LODs para
  los grupos una vez; la caché de grupos retiene solo el último modelo.
- Esta preparación añade trabajo a la primera carga; las siguientes instancias
  reutilizan la geometría. No es streaming asíncrono ni elimina el coste inicial.
- Se eliminó la construcción doble de la trazada al entrar a pista y se oculta
  su representación antigua cuando se usa la dinámica. También se libera la
  trazada dinámica al volver al garaje.

La pista **todavía construye carretera, terreno y colisiones de forma síncrona**.
Ocultar chunks lejanos no equivale a generarlos/cargarlos bajo demanda ni a
liberar toda su memoria. Sigue siendo una limitación pendiente para rutas largas.

## Comprobación reproducible en escritorio

```powershell
godot_console --headless --path . --script tests/wheel_rig_checks.gd
godot_console --path . --rendering-method gl_compatibility --script tools/vehicle_render_probe.gd -- porsche_992_gt3_rs_2024 --unbatched
godot_console --path . --rendering-method gl_compatibility --script tools/vehicle_render_probe.gd -- porsche_992_gt3_rs_2024 --repeat
```

El diagnóstico no modifica preferencias. Desactiva VSync únicamente en su
proceso, mide 120 fotogramas tras 60 de calentamiento y guarda una captura en
`user://qa/alignment/`. No sustituye a una medición de carrera completa.

Referencia de la API utilizada para LODs:
[Godot ImporterMesh](https://docs.godotengine.org/en/stable/classes/class_importermesh.html).
