"Actúa como un experto Diseñador de Niveles y Desarrollador de Entornos 3D para Godot Engine. Necesito recrear un mapa urbano 3D basado en el área de La Sagrera y Sant Martí de Provençals en Barcelona. Ya tengo los assets de ciudad (edificios, carreteras, props), por lo que necesito que generes una guía técnica de diseño de nivel para colocar estos elementos de forma coherente con la realidad capturada en el mapa.

Especificaciones del Área:

Eje Central (Avenida Meridiana): Describe la Avenida Meridiana como una arteria principal de 8 carriles (4 por sentido) que cruza el mapa en diagonal. Debe dividir el mapa en dos zonas: una más residencial/clásica y otra con parques y equipamientos.

Zona Norte (Parque de la Pegaso): Describe un área verde abierta con caminos orgánicos y elevaciones suaves, rodeada por edificios de viviendas de altura media (6-8 plantas).

Trazado de Calles: Explica cómo las calles (como Calle de Felip II y Calle de Garcilaso) cortan la cuadrícula principal, creando esquinas en chaflán (típicas de Barcelona) y plazas pequeñas.

Puntos de Referencia (Landmarks):

Puente de Bac de Roda: Un hito arquitectónico al sur que conecta el área.

Mercado de Provençals: Una estructura baja y amplia que rompe la verticalidad de los edificios circundantes.

Hotel Acta Laumon: Un edificio más moderno y esbelto que sirve como punto de orientación visual.

Zonificación de Assets:

Asigna edificios residenciales antiguos a la zona oeste de la Meridiana.

Asigna edificios de oficinas y hoteles modernos al área de Sant Martí (este).

Coloca mobiliario urbano (farolas, bancos, paradas de autobús) densamente cerca del metro La Sagrera.

Formato de Salida Requerido:
Genera un documento que incluya:

Un esquema de coordenadas relativas (X, Z) para los puntos principales de interés.

Una descripción de la jerarquía de calles (anchura de nodos de carretera).

Sugerencias sobre cómo usar GridMaps o MultiMeshInstance3D en Godot para optimizar la carga de los edificios en esta área específica.

(Opcional) Un ejemplo de script de GDScript para instanciar automáticamente bloques de edificios siguiendo el patrón de cuadrícula de este mapa."

Consejos adicionales para Godot:
Escala: Recuerda que en Godot, 1 unidad suele ser 1 metro. La Avenida Meridiana en la realidad tiene unos 40-50 metros de ancho de fachada a fachada.

Orientación: En la imagen, la Meridiana sube hacia el Noroeste. Asegúrate de rotar tus mallas de carretera unos 15-20 grados para dar esa sensación natural de ciudad real.

Assets: Si tus assets tienen diferentes variaciones, pide a tu LM que te dé una "distribución porcentual" (ej: 70% residencial, 20% comercial, 10% industrial) para que el mapa no se sienta repetitivo.