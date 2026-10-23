# Ideas de Box3D aplicables a APEX REBOOT

Fuente: https://github.com/Miguel249/Box3D.NET (binding C# de Box3D, Erin Catto).

## Conceptos a portar (GDScript)

- **Masa desde formas**: calcular mass/inertia a partir de la geometría del vehículo (no solo mass_kg fijo). Aplicar a vehicle_collision_shape.gd.
- **Load sensitivity**: fricción por newton decrece con carga (implementado en tyre_forces.gd).
- **Sleeping**: cuerpos que se detienen dejan de costar CPU. Útil para props/vehículos estacionados.
- **Motion locks**: restringir rotación/traslación por eje (ej. moto no vuelca en X).
- **Forces vs impulses**: fuerzas acumulan, impulsos cambian velocidad inmediata. Usar en suspension/contact.
- **Joints**: suspensión como joint (spring-damper) en lugar de raycast manual para mayor realismo.
- **Collision filtering**: capas de colisión para vehículos vs props vs terreno.
- **Heightfield terrain**: terreno como heightfield para mejor colisión y rendimiento.
- **Debug draw**: visualizar contactos, fuerzas, AABB.
- **Continuous collision (bullets)**: para proyectiles/vehículos rápidos evitar tunneling.
- **Restitution/friction por shape**: materiales con mu y e por superficie.

## Prioridad sugerida

1. Load sensitivity (hecho)
2. Mass/inertia desde geometría
3. Sleeping para props
4. Heightfield terrain
5. Joints para suspensión
