# Resumen Ejecutivo — Análisis de Ventas E-commerce

**Para:** Equipo directivo
**De:** Análisis de Datos
**Base analizada:** 2,000 pedidos · 350 clientes · 70 productos · 7 categorías · sep-2024 a sep-2026

---

## Resumen en una línea

El negocio depende de una porción reducida de clientes, tiene una estacionalidad marcada de fin de año, un método de pago con fricción notable en el checkout, y una política de envío que castiga proporcionalmente más a las categorías de ticket bajo. Ninguno de estos cuatro puntos requiere inversión grande para empezar a corregirse.

---

## Hallazgos clave

### 1. La facturación está concentrada en la mitad de la base de clientes

El **48% de los clientes (168 de 350) genera el 80% de la facturación total**. No es una concentración extrema tipo "20/80" clásica, pero sí lo suficiente como para que perder a ese grupo tenga un impacto desproporcionado en los ingresos.

**Implicancia:** un programa de retención (incluso simple, tipo puntos o envío gratis permanente) dirigido a ese 48% probablemente tenga mejor retorno que una campaña de adquisición genérica.

### 2. Las ventas son fuertemente estacionales, con diciembre como pico claro

Diciembre 2025 tuvo un salto de **+80% respecto a noviembre**, y julio y septiembre también mostraron subas fuertes (+42% y +93% en sus respectivos meses). En contraste, octubre 2025 y mayo 2026 tuvieron caídas de -51% y -62% frente al mes anterior.

**Implicancia:** el pico de diciembre exige reforzar stock y logística con anticipación; las caídas de octubre y mayo son ventanas naturales para promociones de reactivación en vez de descuentos permanentes.

### 3. Chile y Uruguay concentran el negocio; México queda rezagado en todas las métricas

Chile y Uruguay lideran en ventas totales (~$68M y ~$65M) y ticket promedio (~$194K ambos). México, en cambio, es el país con menor cantidad de clientes (34), menor ventas totales (~$34M) y el segundo ticket promedio más bajo.

**Implicancia:** México es o bien un mercado desatendido con potencial de crecimiento, o bien un mercado donde el producto/pricing actual no calza — vale la pena una investigación cualitativa antes de decidir si invertir más presupuesto ahí.

### 4. Mercado Pago concentra la tasa de cancelación más alta

Mercado Pago tiene una tasa de cancelación de **18.9%**, la más alta de los 5 métodos, muy por encima de Transferencia (11.9%, la más baja). La diferencia es de 7 puntos porcentuales sobre un volumen similar de pedidos.

**Implicancia:** vale la pena revisar el flujo de checkout con Mercado Pago (tiempos de confirmación, caídas de sesión, límites de la integración) — reducir esa brecha a la del resto de los métodos recuperaría decenas de pedidos por mes.

### 5. El costo de envío pesa mucho más, en proporción, sobre las categorías de ticket bajo

En **Libros**, el envío representa el **10.8% del ticket promedio**; en **Belleza**, el 8.5%. En **Electrónica**, en cambio, es apenas el **0.1%** (porque el ticket es mucho más alto). La política actual de "envío gratis a partir de cierto monto" termina beneficiando casi siempre a Electrónica y casi nunca a Libros o Belleza.

**Implicancia:** condicionar el envío gratis al valor del pedido (en vez de a un monto fijo parejo para todas las categorías) podría mejorar la conversión en las categorías más castigadas sin resignar margen en las que ya tienen envío prácticamente gratis.

### 6. Hay clientes de alto valor que dejaron de comprar hace mucho

Se identificaron clientes con 3 o más pedidos históricos (compradores recurrentes, no ocasionales) cuya última compra fue hace **entre 349 y 587 días**. El caso más notorio es un cliente en España con 6 pedidos históricos y ~$1.53M en gasto acumulado, sin comprar desde enero de 2025.

**Implicancia:** son candidatos ideales para una campaña de reactivación dirigida (no masiva) — ya demostraron ser compradores frecuentes y de ticket alto, el problema no es de perfil sino de reactivación.

---

## Recomendaciones priorizadas

1. **Corto plazo / bajo esfuerzo:** lanzar una campaña de reactivación dirigida a los ~10-20 clientes de alto valor identificados como inactivos (hallazgo 6).
2. **Corto plazo / bajo esfuerzo:** investigar con el equipo de pagos por qué Mercado Pago cancela más que el resto (hallazgo 4).
3. **Mediano plazo:** rediseñar la política de envío gratis para que beneficie proporcionalmente a Libros y Belleza, no solo a Electrónica (hallazgo 5).
4. **Mediano plazo:** diseñar un programa de fidelización para el segmento que explica el 80% de la facturación (hallazgo 1).
5. **Requiere más información:** decidir si invertir en México (adquisición) o ajustar oferta/precio ahí, antes de escalar cualquiera de las dos opciones (hallazgo 3).

## Metodología (resumen)

Los datos se limpiaron previamente (ver la PARTE C de `sql/01_schema_and_data.sql`): se detectaron nulos en fecha de pedido, monto total y costo de envío en 3-5% de los registros, y se resolvieron con `COALESCE` antes de este análisis, para no distorsionar sumas ni promedios. Las 6 preguntas de negocio de este documento están resueltas en la PARTE B de `sql/02_analysis_queries.sql`, usando CTEs y funciones de ventana (`SUM() OVER`, `LAG()`, `ROW_NUMBER()`) sobre las tablas ya limpias.

## Limitaciones

- El dataset es sintético; las cifras absolutas (montos) no representan una empresa real, pero los patrones (concentración, estacionalidad, diferencias por método de pago) se calcularon con la misma metodología que se usaría sobre datos reales.
- "Días sin comprar" se calculó contra la fecha actual del sistema; si este informe se corre en otro momento, esos números van a variar.
