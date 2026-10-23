# HUD de carrera

La interfaz de conducción agrupa los datos de carrera en los bordes y mantiene despejada la zona central de la pista. Utiliza paneles oscuros translúcidos, números blancos y acentos rojos. La marcha tiene el mayor peso visual dentro de los instrumentos.

## Distribución

| Zona | Información |
| --- | --- |
| Arriba a la izquierda | Modo, vuelta o etapa y clasificación de los participantes de la sesión. El jugador se distingue de los rivales. |
| Arriba a la derecha | Tiempo actual, mejor tiempo disponible y estado del intento. En recorridos abiertos se muestra la distancia que falta hasta la meta. |
| Abajo a la izquierda | Minimapa del trazado con la posición de los vehículos. |
| Abajo al centro | Marcha, velocidad en km/h, revoluciones y tres indicadores rojos de pedales. |
| Avisos temporales | Cuenta atrás, salida, invalidación del intento y acontecimientos relevantes de la sesión. |

La distribución se adapta a la ventana y conserva márgenes respecto a los bordes. No es necesario cambiar de HUD al pasar de coche a moto.

## Velocidad, marcha y revoluciones

La velocidad procede de la telemetría del vehículo. La marcha muestra **N** en punto muerto, **R** en reversa y el número correspondiente al avanzar. El indicador de revoluciones se normaliza con el régimen máximo definido en el perfil de cada vehículo; una moto y un monoplaza no tienen por qué compartir la misma escala.

## Pedales rojos

Los tres indicadores presentan valores independientes de **0 a 100 %**:

- **ACEL.**: mando de acelerador aplicado al vehículo.
- **FRENO**: mando de frenada principal.
- **TRASERO** en motos o **MANO** en coches: mando de freno trasero o freno de mano.

El teclado puede alcanzar un valor progresivamente debido al suavizado de entrada. Los gatillos de un mando pueden mantener valores intermedios. Las barras indican el mando aplicado, no la fuerza final del neumático: ABS, control de tracción, agarre y contacto con el suelo pueden modificar esa fuerza. Durante la cuenta atrás, el sistema mantiene la frenada de los vehículos.

## Carrera, contrarreloj y recorrido abierto

La clasificación utiliza los participantes reales y su progreso en la sesión. Un abandono se distingue con **DNF**. En sesiones individuales se priorizan el modo y los tiempos, sin añadir rivales ficticios.

La columna de diferencias toma al jugador como referencia: un valor negativo corresponde a un rival por delante y uno positivo a un rival por detrás. Los segundos se obtienen de los tiempos de paso por el mismo punto del recorrido. Si todavía faltan muestras se muestra **—**; una diferencia de vueltas completas se expresa con **V**. El historial se reinicia al recolocar el vehículo.

Los tiempos proceden del seguimiento de vueltas y etapas. Cuando todavía no existe un mejor tiempo válido, se muestra un marcador vacío. Una vuelta o etapa invalidada se distingue de un intento válido. Un recorrido abierto tiene una única llegada y muestra los metros restantes; no se presenta como una sucesión de vueltas cerradas.

Los indicadores de progreso del trazado describen la posición dentro del recorrido. No equivalen por sí solos a sectores cronometrados ni acreditan una mejora respecto a otra vuelta.

## Ayuda y telemetría

La pantalla normal de conducción no mantiene una lista de teclas, el nombre de la cámara ni lecturas técnicas como carga aerodinámica, contacto de ruedas o ángulo de dirección. Las asignaciones se consultan y modifican en **Pausa → Ajustes → Controles**; también están documentadas en [Controles](CONTROLS.md).

**F3** muestra u oculta la telemetría detallada. Ese panel permite consultar los datos físicos y de asistencias cuando se necesitan. Los avisos de daño o vehículo inmovilizado aparecen según el estado de la sesión, evitando mantener un mensaje de “sin daños” durante toda la conducción.

**Esc** sigue abriendo la pausa aunque no exista una etiqueta permanente en el HUD. El modo foto **F6** oculta el HUD y permite guardar una captura con **F12**.

El rediseño cambia cómo se presenta la información. Los perfiles de vehículos, la dinámica, el rebufo, las colisiones y las reglas de validez conservan su funcionamiento.

## Tipografía

El HUD utiliza **Barlow Semi Condensed**, con los pesos Medium, SemiBold y Bold para distinguir etiquetas, cifras y la marcha. Los archivos de la fuente y su procedencia están en `assets/fonts/barlow/`. Se distribuyen con la licencia **SIL Open Font License 1.1** y el aviso de autoría incluidos en esa carpeta. El uso de esta fuente en el HUD no cambia el contenido de los datos de conducción.
