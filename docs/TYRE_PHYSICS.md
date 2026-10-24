# Fuerzas de las llantas y estabilidad del Porsche

## Fallos corregidos

- `cornering_stiffness` llegaba a cada contacto pero el solver lo ignoraba. Ahora controla la pendiente inicial de la fuerza lateral y su saturación mediante una aproximación de cepillo.
- Una referencia de carga fija de 2000 N penalizaba por igual neumáticos que soportan pesos diferentes. Los contactos usan como referencia su carga estática por rueda; la transferencia de carga y la aerodinámica siguen afectando el límite de adherencia.
- La temperatura se calculaba para todo el vehículo usando la carga de la primera rueda y el mayor deslizamiento. Ahora cada llanta conserva y actualiza su propia temperatura; la telemetría agregada muestra la media.
- La inercia de giro de los coches utilizaba la distancia entre ejes. Ahora se estima con longitud y anchura completas de la carrocería. Las posiciones de los ejes ya incorporan el reparto de peso: no se desplaza otra vez el centro de masas longitudinal.

## Parámetros por eje

Los perfiles aceptan `front_tyre` y `rear_tyre`: `cornering_stiffness`, `cornering_stiffness_n_per_rad`, `reference_load_n`, `load_sensitivity`, `grip_scale` y `width_mm`. Un coeficiente explícito N/rad tiene prioridad sobre la estimación. El ancho modifica suavemente la rigidez estimada; no multiplica directamente el agarre máximo. Las fuerzas longitudinales y laterales continúan compartiendo un presupuesto limitado por carga y fricción.

Se incorporaron las dimensiones declaradas por Porsche: 275/35 R20 delante y 335/30 R21 detrás.
Fuente: https://newsroom.porsche.com/en/2022/products/porsche-911-gt3-rs-world-premiere-29177.html

Referencia conceptual del modelo de cepillo y sus limitaciones: https://api.projectchrono.org/development/wheeled_tire.html

Los coeficientes de rigidez, fricción y sensibilidad a la carga siguen siendo estimaciones del simulador. No son curvas experimentales del fabricante. No se implementan todavía deformación completa de carcasa, presión, desgaste ni una dinámica angular independiente de cada rueda; el patinaje longitudinal sigue estimándose a partir de la demanda de fuerza. Tampoco se simula la dirección trasera activa del vehículo real.

## Verificación

    godot_console --headless --path . --fixed-fps 120 --script tests/tyre_handling_checks.gd
    godot_console --headless --path . --fixed-fps 120 --script tests/physics_checks.gd
    godot_console --headless --path . --fixed-fps 120 --script tests/formula_handling_checks.gd
    godot_console --headless --path . --fixed-fps 120 --script tests/ai_lap_checks.gd

La regresión del Porsche usa el perfil del juego en Sport, asfalto seco, salida a 80 km/h y sin acelerar, con órdenes de dirección de 0,15 y 0,35 durante tres segundos. Verifica ausencia de trompo, pérdida de apoyo y daños. No certifica todos los límites del coche ni su fidelidad al fabricante.
