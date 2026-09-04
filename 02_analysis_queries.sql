-- =====================================================================
-- 02_analysis_queries.sql
-- TODAS las consultas de analisis, comentadas, en un unico archivo:
--   - 4 consultas base (top clientes, ventas por mes, productos menos
--     vendidos, ranking por categoria con RANK())
--   - 6 preguntas de negocio complejas (Pareto de clientes, crecimiento
--     mes a mes, desempeno por pais, metodo de pago vs. cancelaciones,
--     peso del envio por categoria, clientes valiosos inactivos)
-- Todas usan CTEs (WITH) y, donde corresponde, window functions
-- (RANK, SUM() OVER, LAG, ROW_NUMBER).
--
-- Ejecutar conectado a la base capstone_project, DESPUES de
-- 01_schema_and_data.sql (que ya incluye la limpieza):
--   psql -U postgres -d capstone_project -f 02_analysis_queries.sql
-- =====================================================================

-- =====================================================================
-- PARTE A: Consultas base
-- =====================================================================

-- Todas las tablas viven en el esquema "project".
SET search_path TO project;

-- ---------------------------------------------------------------------
-- 1) TOP 5 CLIENTES POR GASTO TOTAL (CTE + GROUP BY + SUM)
-- ---------------------------------------------------------------------
WITH gasto_por_cliente AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_country,
        COUNT(p.order_id)   AS cantidad_pedidos,
        SUM(p.total_amount) AS gasto_total
    FROM pedidos p
    JOIN clientes c ON c.customer_id = p.customer_id
    GROUP BY c.customer_id, c.customer_name, c.customer_country
)
SELECT *
FROM gasto_por_cliente
ORDER BY gasto_total DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 2) VENTAS TOTALES POR MES (CTE + funciones de fecha)
-- ---------------------------------------------------------------------
WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS mes,
        COUNT(order_id)                       AS cantidad_pedidos,
        SUM(total_amount)                     AS ventas_totales
    FROM pedidos
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT *
FROM ventas_mensuales
ORDER BY mes;

-- ---------------------------------------------------------------------
-- 3) 3 PRODUCTOS MENOS VENDIDOS (CTE; LEFT JOIN para incluir productos
--    sin ninguna venta registrada)
-- ---------------------------------------------------------------------
WITH ventas_por_producto AS (
    SELECT
        pr.product_id,
        pr.product_name,
        cat.nombre                   AS categoria,
        COALESCE(SUM(p.quantity), 0) AS unidades_vendidas
    FROM productos pr
    JOIN categoria cat ON cat.categoria_id = pr.categoria_id
    LEFT JOIN pedidos p ON p.product_id = pr.product_id
    GROUP BY pr.product_id, pr.product_name, cat.nombre
)
SELECT *
FROM ventas_por_producto
ORDER BY unidades_vendidas ASC
LIMIT 3;

-- ---------------------------------------------------------------------
-- 4) RANKING DE PEDIDOS POR CATEGORIA (CTE + Window Function RANK())
--    La CTE arma el detalle (pedido + producto + categoria); la
--    consulta final aplica RANK() sobre ese resultado ya simplificado.
-- ---------------------------------------------------------------------
WITH pedidos_detalle AS (
    SELECT
        cat.nombre AS categoria,
        p.order_id,
        pr.product_name,
        p.total_amount
    FROM pedidos p
    JOIN productos pr ON pr.product_id = p.product_id
    JOIN categoria cat ON cat.categoria_id = pr.categoria_id
)
SELECT
    categoria,
    order_id,
    product_name,
    total_amount,
    RANK() OVER (
        PARTITION BY categoria
        ORDER BY total_amount DESC
    ) AS ranking_en_categoria
FROM pedidos_detalle
ORDER BY categoria, ranking_en_categoria
LIMIT 30;  -- top 30 filas de muestra (quitar el LIMIT para ver todo)

-- =====================================================================
-- PARTE B: Preguntas de negocio complejas
-- =====================================================================

-- ---------------------------------------------------------------------
-- P1) CONCENTRACION DE INGRESOS: ¿que porcentaje de clientes genera
--     el 80% de la facturacion? (analisis tipo Pareto / 80-20)
-- ---------------------------------------------------------------------
WITH gasto_cliente AS (
    SELECT customer_id, SUM(total_amount) AS gasto
    FROM pedidos
    GROUP BY customer_id
),
acumulado AS (
    SELECT
        customer_id,
        gasto,
        ROW_NUMBER() OVER (ORDER BY gasto DESC)      AS orden,
        SUM(gasto) OVER (ORDER BY gasto DESC)        AS gasto_acumulado,
        SUM(gasto) OVER ()                           AS gasto_total_empresa
    FROM gasto_cliente
)
SELECT
    COUNT(*) FILTER (WHERE gasto_acumulado <= 0.8 * gasto_total_empresa) AS clientes_que_explican_80pct,
    COUNT(*)                                                             AS total_clientes,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE gasto_acumulado <= 0.8 * gasto_total_empresa)
        / COUNT(*), 1
    ) AS pct_clientes_que_explican_80pct
FROM acumulado;

-- ---------------------------------------------------------------------
-- P2) CRECIMIENTO MES A MES: ¿como varian las ventas totales respecto
--     al mes anterior (%), y en que meses hubo caidas?
-- ---------------------------------------------------------------------
WITH ventas_mes AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS mes,
        SUM(total_amount)                     AS ventas
    FROM pedidos
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    mes,
    ventas,
    LAG(ventas) OVER (ORDER BY mes) AS ventas_mes_anterior,
    ROUND(
        100.0 * (ventas - LAG(ventas) OVER (ORDER BY mes))
        / NULLIF(LAG(ventas) OVER (ORDER BY mes), 0), 1
    ) AS variacion_pct_mom
FROM ventas_mes
ORDER BY mes;

-- ---------------------------------------------------------------------
-- P3) DESEMPEÑO POR PAIS: ¿que paises tienen mejor ticket promedio y
--     mayor frecuencia de compra por cliente? (para priorizar foco
--     comercial/geografico)
-- ---------------------------------------------------------------------
WITH metricas_pais AS (
    SELECT
        c.customer_country,
        COUNT(DISTINCT c.customer_id)                                    AS clientes,
        COUNT(p.order_id)                                                AS pedidos,
        SUM(p.total_amount)                                              AS ventas_totales,
        ROUND(AVG(p.total_amount), 2)                                    AS ticket_promedio,
        ROUND(COUNT(p.order_id)::NUMERIC / COUNT(DISTINCT c.customer_id), 2) AS pedidos_por_cliente
    FROM clientes c
    JOIN pedidos p ON p.customer_id = c.customer_id
    GROUP BY c.customer_country
)
SELECT *
FROM metricas_pais
ORDER BY ventas_totales DESC;

-- ---------------------------------------------------------------------
-- P4) METODO DE PAGO VS. CANCELACIONES: ¿algun metodo de pago concentra
--     una tasa de cancelacion mas alta que el resto?
-- ---------------------------------------------------------------------
WITH pagos AS (
    SELECT
        payment_method,
        COUNT(*)                                              AS total_pedidos,
        COUNT(*) FILTER (WHERE order_status = 'Cancelado')    AS cancelados,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE order_status = 'Cancelado') / COUNT(*), 1
        ) AS tasa_cancelacion_pct,
        SUM(total_amount)                                     AS ventas_totales
    FROM pedidos
    GROUP BY payment_method
)
SELECT *
FROM pagos
ORDER BY tasa_cancelacion_pct DESC;

-- ---------------------------------------------------------------------
-- P5) PESO DEL ENVIO SOBRE EL TICKET, POR CATEGORIA: ¿en que categorias
--     el costo de envio representa una porcion mas alta del valor del
--     pedido? (candidatas a revisar politica de envio gratis)
-- ---------------------------------------------------------------------
WITH envio_categoria AS (
    SELECT
        cat.nombre                                                       AS categoria,
        ROUND(AVG(p.total_amount), 2)                                    AS ticket_promedio,
        ROUND(AVG(p.shipping_cost), 2)                                   AS envio_promedio,
        ROUND(100.0 * AVG(p.shipping_cost) / NULLIF(AVG(p.total_amount), 0), 1) AS pct_envio_sobre_ticket
    FROM pedidos p
    JOIN productos pr ON pr.product_id = p.product_id
    JOIN categoria cat ON cat.categoria_id = pr.categoria_id
    GROUP BY cat.nombre
)
SELECT *
FROM envio_categoria
ORDER BY pct_envio_sobre_ticket DESC;

-- ---------------------------------------------------------------------
-- P6) CLIENTES VALIOSOS EN RIESGO DE ABANDONO: clientes con 3 o mas
--     pedidos historicos (compradores recurrentes) cuya ultima compra
--     es la mas antigua en relacion al resto -> candidatos a campaña
--     de reactivacion.
-- ---------------------------------------------------------------------
WITH actividad_cliente AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_country,
        COUNT(p.order_id)      AS pedidos_totales,
        MAX(p.order_date)      AS ultima_compra,
        SUM(p.total_amount)    AS gasto_total
    FROM clientes c
    JOIN pedidos p ON p.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.customer_country
)
SELECT
    customer_id,
    customer_name,
    customer_country,
    pedidos_totales,
    ultima_compra,
    gasto_total,
    (CURRENT_DATE - ultima_compra) AS dias_sin_comprar
FROM actividad_cliente
WHERE pedidos_totales >= 3
ORDER BY ultima_compra ASC
LIMIT 10;
