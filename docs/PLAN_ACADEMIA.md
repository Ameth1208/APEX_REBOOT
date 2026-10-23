# Plan: Simulador de conducción para academia

Objetivo: simulador de conducción seguro con carreteras reales de la zona, física de suspensión realista y vehículos comerciales.

## Fases

1. **Repositorio y trazabilidad** (hecho)
   - Repo privado GitHub: Ameth1208/APEX_REBOOT
   - Git local configurado (amethgm@gmail.com)

2. **Vehículos comerciales**
   - Definir lista de autos a modelar (marca/modelo/año)
   - Crear perfil JSON por vehículo (basado en senna/porsche)
   - Añadir a data/vehicles/catalog.json
   - Modelar en Blender, exportar GLB a assets/vehicles/<id>/

3. **Física y suspensión**
   - Ajustar parámetros en scripts/physics/suspension.gd y vehicle_forces.gd
   - Validar con race.software / datos de suspensión
   - Pruebas en pista (F8 diagnóstico)

4. **Carreteras reales de zona**
   - Importar GPX/GeoJSON de la zona (F2 → Ruta real)
   - Obtener cotas SRTM/Copernicus
   - Validar perfil, pendientes, cruces
   - Ajustar anchura/peralte por tramo

5. **Terreno inteligente y assets**
   - Modelar módulos de terreno en Blender
   - Exportar GLB y integrar en Godot
   - Generar vegetación/señalización por tipo de zona

6. **Validación**
   - Pruebas de manejo en ruta real
   - Ajuste de dificultad y asistencias
   - Documentar en docs/VALIDATION.md

## Entregables inmediatos

- [ ] Lista de vehículos comerciales a modelar
- [ ] Primera ruta real de la zona (GPX/GeoJSON)
- [ ] Perfil JSON del primer vehículo comercial
- [ ] Asset de terreno base en Blender

## Notas

- Blender MCP configurado para edición de assets.
- Godot 4.7.2 instalado para trabajar en el proyecto.
- Física a 120 Hz, no cambiar sin validar.
