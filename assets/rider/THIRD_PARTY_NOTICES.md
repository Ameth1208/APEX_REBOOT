# Piloto humano: autoría, fuente y adaptaciones

El piloto principal usa **Superhero Male FullBody**, del paquete **Universal Base Characters [Standard]** de **Quaternius**. Es un modelo humano de autor con malla, esqueleto, skin y texturas; no representa a un piloto real concreto.

- Autor y página del paquete: https://quaternius.com/packs/universalbasecharacters.html
- Descarga oficial gratuita: https://quaternius.itch.io/universal-base-characters
- Archivo del autor: `Universal Base Characters[Standard].zip`, descarga pública `15861669`, obtenido el 20 de octubre de 2026.
- Condiciones incluidas por el autor: **CC0 1.0 Universal**, conservadas sin modificaciones en `quaternius/License_Standard.txt`.
- Texto completo de CC0: `quaternius/CC0-1.0.txt`, obtenido del repositorio oficial de Creative Commons, https://raw.githubusercontent.com/creativecommons/cc-legal-tools-data/main/docs/publicdomain/zero/1.0/legalcode.txt
- Resumen oficial de CC0: https://creativecommons.org/publicdomain/zero/1.0/
- Procedencia y SHA-256 del ZIP y de cada recurso integrado: `quaternius/source-audit.json`.

Se conserva el glTF original y su BIN sin alterar. Sus texturas originales también se conservan; dos copias usan los alias de nombre que referencia el propio glTF (`T_Hair_1_Normal_png.png` y `T_Eye_Normal_png.png`). La relación con los miembros exactos del ZIP está en el archivo de auditoría.

Adaptaciones de esta aplicación: giro de 180°, escala uniforme de 0,98, postura sobre la Yamaha mediante cinemática inversa de brazos y piernas, flexión de dedos, postura dependiente de velocidad/inclinación, material de mono/guantes creado en ejecución y ocultación de cabeza/torso para la cámara de piloto. El casco y las cubiertas de las botas son geometría original creada para este proyecto. No se altera el esqueleto ni el peso de los vértices de los archivos fuente. El material del mono sustituye visualmente la piel cubierta; la cara conserva las texturas del autor.

El piloto procedural anterior permanece como alternativa opcional o de respaldo si falta el recurso humano. CesiumMan se evaluó y no forma parte del producto.

Las condiciones de este personaje no cambian las de los vehículos del usuario. Consulta `assets/vehicles/THIRD_PARTY_NOTICES.md` para Porsche, Yamaha, Ferrari y el monoplaza Senna.
