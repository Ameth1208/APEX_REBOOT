# Controles

Las asignaciones predeterminadas proceden de `scripts/app/input_setup.gd`. En **Ajustes → Controles** puedes reasignar las diez acciones de conducción y restaurar las predeterminadas. La captura rechaza teclas ya usadas y modificadores; Esc cancela. Los botones de Ajustes reflejan la nueva tecla. La pantalla normal de conducción no mantiene una guía de controles; puedes consultarla desde la pausa o en este documento. En Web se muestra el nombre de la tecla física. Los botones/ejes del mando se conservan al cambiar el teclado. Se admiten teclado y mandos que Godot reconozca mediante su mapeo de botones. En las tablas se usa la nomenclatura Xbox y, entre paréntesis, la posición/equivalente habitual de PlayStation.

## Conducir

| Acción | Teclado | Mando |
| --- | --- | --- |
| Acelerar | W o flecha arriba | Gatillo derecho RT/R2. |
| Frenar | S o flecha abajo | Gatillo izquierdo LT/L2. |
| Girar | A/D o flechas izquierda/derecha | Eje horizontal del stick izquierdo. |
| Freno trasero / freno de mano | Espacio | A, botón inferior (cruz). |
| Solicitar marcha atrás | Mantener V | Mantener LB/L1. |
| Subir marcha | E | B, botón derecho (círculo). |
| Bajar marcha | Q | X, botón izquierdo (cuadrado). |
| Recolocar y reparar | R | Back/View (Share/Create, según mapeo). |
| Cambiar cámara | C | Y, botón superior (triángulo). |
| Pausa | Esc | Start/Menu (Options). |

Usa marcha atrás con el vehículo casi detenido. Mantener V/LB solicita tracción inversa aunque no mantengas el acelerador. La transmisión automática se cambia en **Ajustes → Conducción → Cambio**; Q/E y sus botones equivalentes permiten controlar las marchas en modo manual.

La dirección por teclado se suaviza para evitar cambios instantáneos. En la moto, la entrada solicita manillar a baja velocidad e inclinación cuando aumenta la velocidad; el piloto virtual mantiene el equilibrio. El freno trasero no equivale a la frenada principal de la moto.

Recolocar repara los daños y recupera una moto caída, pero invalida el intento actual. En circuito cerrado borra las puertas de control acumuladas. En etapa abierta conserva únicamente los sectores que ya visitaste para permitir llegar a meta con tiempo inválido; nunca concede mejor tiempo ni progreso de campeonato. Reinicia la sesión si quieres registrar un intento válido.

## Juego y visualización

| Acción | Tecla | Efecto |
| --- | --- | --- |
| Editor de circuitos | F2 | Pausa y abre el diseño de la pista actual. |
| Telemetría | F3 | Muestra u oculta información física y de asistencias. |
| Piloto automático | F4 | Activa/desactiva la conducción IA del vehículo del jugador. |
| Día / noche | N | Alterna la iluminación de la sesión. |
| Faros | L | Activa/desactiva los faros durante la conducción. |
| Modo foto | F6 | Pausa el vehículo y activa vista orbital con HUD oculto. |
| Guardar captura | F12 | Escribe una imagen PNG en `user://photos/`. |

F2, F3, F4, F6, F12, N y L no tienen un botón de mando dedicado en la configuración actual. Se pueden utilizar desde el teclado mientras el mando está conectado.

El piloto F4 usa los mismos cuerpos y fuerzas que los rivales. **Una sesión en la que se utilizó F4 no concede progreso de campeonato**, aunque se apague antes de terminar. La conducción Asistida/Sport y la trazada orientativa son ajustes distintos del piloto automático.

## Cámaras y modo foto

C recorre cinco vistas:

1. **Persecución:** seguimiento detrás del vehículo.
2. **Capó / depósito:** vista cercana delantera, adaptada a coche o moto.
3. **Piloto:** posición configurada en el perfil del vehículo. En la moto se ocultan las partes del piloto que taparían la visión.
4. **Cinemática:** seguimiento lateral y elevado.
5. **Orbital:** vista giratoria controlada con el ratón.

En el garaje, la vista orbital y el modo foto:

| Acción | Ratón |
| --- | --- |
| Girar y variar elevación | Mantener botón derecho y arrastrar. |
| Acercar o alejar | Rueda. |

Para una foto sin HUD: pulsa **F6**, encuadra con el ratón, pulsa **F12** y vuelve con **F6**. F12 también captura la vista actual fuera del modo foto; en ese caso incluye la interfaz visible.

## Editor de circuitos

| Acción | Control |
| --- | --- |
| Seleccionar un punto | Clic izquierdo sobre el marcador. |
| Cambiar X/Z | Arrastrar el punto con botón izquierdo. |
| Ajustar a cuadrícula de 10 m | Mantener Mayús al arrastrar. |
| Añadir un punto | Doble clic; se inserta en el tramo más cercano. |
| Eliminar | Botón del panel o Suprimir con el mapa enfocado. |
| Desplazar mapa | Arrastrar con botón central. |
| Zoom del mapa | Rueda. |
| Centrar toda la pista | Botón Centrar. |
| Cambiar altura/peralte/anchura | Campos numéricos del panel derecho. |
| Deshacer / rehacer | Botones Deshacer y Rehacer. |
| Probar cambios | Aplicar y conducir. |
| Conservar cambios | Guardar. |

Los controles del editor son de ratón/teclado. **Aplicar no guarda automáticamente el JSON**. Al aplicar, se inicia una sesión con el nuevo trazado. Si estabas en campeonato, la sesión pasa a **Libre** para utilizar tu diseño. [TRACK_EDITOR.md](TRACK_EDITOR.md) explica superficies, imágenes propias e importación/exportación.

## Ajustes útiles

Desde el garaje o la pausa puedes elegir cambio automático/manual, asistencias, trazada, carga aerodinámica, agarre, humedad, volumen, calidad y pantalla completa. Las preferencias se guardan para la siguiente sesión. Para probar una configuración conocida, comienza con Sport, cambio automático, día seco, multiplicadores de carga/agarre en 1.0 y pocos rivales.

Si una tecla no actúa, cierra primero el diálogo o campo de texto que tenga el foco. Los menús y los campos del editor reciben las teclas antes que los atajos de conducción.

## HUD de entradas y pantalla

El [HUD de 0.3.1](HUD.md) distribuye clasificación, tiempos y minimapa en los bordes y agrupa marcha, velocidad, RPM y pedales al centro inferior. Esc sigue abriendo la pausa aunque no aparezca una etiqueta permanente. La telemetría detallada se muestra solo al activarla con F3.

Las barras rojas de **ACELERADOR**, **FRENO** y **FRENO DE MANO** —**FRENO TRASERO** en la moto— muestran porcentajes separados de 0 a 100. Acelerador y freno reflejan los comandos suavizados que utiliza el modelo de motor/frenada, tanto del jugador como del piloto IA. Por ello el teclado sube gradualmente hasta el 100 % y un gatillo puede mantener valores intermedios. El freno trasero/de mano conserva su entrada independiente.

Estas barras no miden la fuerza longitudinal efectiva del neumático: ABS, control de tracción, contacto y agarre pueden modificar la fuerza finalmente transmitida. F3 muestra las ayudas activas y los contactos. Durante la cuenta atrás, la simulación mantiene el freno.

La ventana es redimensionable. El escalado de interfaz conserva proporciones y el modo expand aprovecha el ancho/alto disponible en relaciones 16:9, 16:10, 4:3 y ultrapanorámicas. Los indicadores se anclan a los bordes con márgenes; los paneles largos del editor se desplazan. Pantalla completa se controla desde Ajustes.

En la Yamaha, las cámaras Persecución, Depósito y Piloto giran con la inclinación visible de la moto, incluyendo peralte y movimiento del piloto virtual. La rotación se suaviza según el tiempo transcurrido. Las cámaras Cinemática y Orbital mantienen su encuadre externo.

## Ajustes de conducción y cámara · 0.3

| Ajuste | Efecto | Valor inicial |
| --- | --- | --- |
| Respuesta de dirección | Rapidez con que el mando solicitado llega a la dirección. | 1,0×. |
| Curva de stick | Un valor mayor suaviza el centro del eje; sigue alcanzando el 100 %. | 1,2×. |
| Curva de pedales | Modifica la progresión de gatillos; no sustituye ABS/TCS. | 1,0×. |
| Zona muerta de dirección | Ignora movimientos pequeños del stick alrededor del centro. | 0,12. |
| Zona muerta de gatillos | Ignora entrada pequeña residual del gatillo. | 0,03. |
| Nivel de rivales | Accesible, Normal o Experto; cambia el margen de conducción, no la potencia. | Normal. |
| Campo de visión vertical | FOV de base; conserva ampliación moderada con velocidad. | 65°. |
| Acompañar inclinación | De horizonte nivelado a acompañamiento completo de la moto. | 1,0, completo. |
| Movimiento de cabeza | Movimiento visual por aceleración, terreno e impactos; 0 lo desactiva. | 0,55. |

Estos ajustes se guardan automáticamente. Las preferencias de cámara solo afectan a la imagen: no cambian la orientación física ni la inclinación de la moto. Los mandos deben ser reconocidos por Godot; no se han ensayado todos los dispositivos físicos. La reasignación disponible es de teclado, no un editor de ejes ni force feedback de volante.

El HUD muestra avisos de daño o moto caída cuando corresponde; el detalle de motor, dirección y aerodinámica se consulta en la telemetría. La clasificación se actualiza durante la carrera. **Pausa → Retirarme · DNF** termina la sesión y muestra resultados sin premiar campeonato. La pantalla final permite volver a correr o regresar al garaje.
