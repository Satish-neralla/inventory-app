-- =====================================================================
-- 001_create_tables.sql
-- Inventory App: core schema (catalog, warehouses, stock)
--
-- Run as:   inventory_user
-- Database: cfapi
-- The whole script runs in one transaction: if anything fails,
-- nothing is created.
-- =====================================================================

BEGIN;

SET search_path TO inventory;

-- ---------------------------------------------------------------------
-- Shared trigger function: keeps updated_at current on every UPDATE
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- categories
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id           bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         varchar(100) NOT NULL UNIQUE,
    description  text,
    is_active    boolean      NOT NULL DEFAULT true,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    updated_at   timestamptz  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- suppliers
-- ---------------------------------------------------------------------
CREATE TABLE suppliers (
    id            bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          varchar(150) NOT NULL UNIQUE,
    contact_name  varchar(100),
    email         varchar(255),
    phone         varchar(30),
    address       text,
    is_active     boolean      NOT NULL DEFAULT true,
    created_at    timestamptz  NOT NULL DEFAULT now(),
    updated_at    timestamptz  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- warehouses
-- ---------------------------------------------------------------------
CREATE TABLE warehouses (
    id          bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        varchar(20)  NOT NULL UNIQUE,
    name        varchar(100) NOT NULL,
    location    varchar(255),
    is_active   boolean      NOT NULL DEFAULT true,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- products
-- Products are deactivated (is_active = false), never deleted,
-- because stock history references them.
-- ---------------------------------------------------------------------
CREATE TABLE products (
    id             bigint        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku            varchar(50)   NOT NULL UNIQUE,
    name           varchar(150)  NOT NULL,
    description    text,
    category_id    bigint        NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    supplier_id    bigint        REFERENCES suppliers(id) ON DELETE SET NULL,
    unit           varchar(20)   NOT NULL DEFAULT 'pcs',
    cost_price     numeric(12,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
    sale_price     numeric(12,2) NOT NULL DEFAULT 0 CHECK (sale_price >= 0),
    reorder_level  integer       NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
    is_active      boolean       NOT NULL DEFAULT true,
    created_at     timestamptz   NOT NULL DEFAULT now(),
    updated_at     timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_category ON products (category_id);
CREATE INDEX idx_products_supplier ON products (supplier_id);

-- ---------------------------------------------------------------------
-- stock_levels: current quantity per product per warehouse
-- ---------------------------------------------------------------------
CREATE TABLE stock_levels (
    product_id    bigint      NOT NULL REFERENCES products(id)   ON DELETE RESTRICT,
    warehouse_id  bigint      NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    quantity      integer     NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, warehouse_id)
);

CREATE INDEX idx_stock_levels_warehouse ON stock_levels (warehouse_id);

-- ---------------------------------------------------------------------
-- stock_movements: append-only ledger of every stock change
-- quantity_change is signed: positive adds stock, negative removes it.
-- The direction check stops e.g. a SALE from adding stock.
-- ---------------------------------------------------------------------
CREATE TABLE stock_movements (
    id               bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id       bigint       NOT NULL REFERENCES products(id)   ON DELETE RESTRICT,
    warehouse_id     bigint       NOT NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
    movement_type    varchar(20)  NOT NULL
        CHECK (movement_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT',
                                 'TRANSFER_IN', 'TRANSFER_OUT', 'RETURN')),
    quantity_change  integer      NOT NULL CHECK (quantity_change <> 0),
    reference        varchar(100),
    notes            text,
    created_at       timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT chk_movement_direction CHECK (
           (movement_type IN ('PURCHASE', 'TRANSFER_IN', 'RETURN') AND quantity_change > 0)
        OR (movement_type IN ('SALE', 'TRANSFER_OUT')              AND quantity_change < 0)
        OR (movement_type = 'ADJUSTMENT')
    )
);

CREATE INDEX idx_movements_product_warehouse ON stock_movements (product_id, warehouse_id);
CREATE INDEX idx_movements_created_at        ON stock_movements (created_at);

-- ---------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_categories_updated_at   BEFORE UPDATE ON categories   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_suppliers_updated_at    BEFORE UPDATE ON suppliers    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_warehouses_updated_at   BEFORE UPDATE ON warehouses   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated_at     BEFORE UPDATE ON products     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_stock_levels_updated_at BEFORE UPDATE ON stock_levels FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
