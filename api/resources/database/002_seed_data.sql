-- =====================================================================
-- 002_seed_data.sql
-- Inventory App: sample data for local development
--
-- Run as:   inventory_user
-- Database: cfapi
-- Run AFTER 001_create_tables.sql. Rows are linked by their natural
-- keys (category name, SKU, warehouse code), never by hard-coded ids.
-- =====================================================================

BEGIN;

SET search_path TO inventory;

-- ---------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------
INSERT INTO categories (name, description) VALUES
    ('Electronics',     'Computer accessories and electronic devices'),
    ('Office Supplies', 'Paper, stationery and everyday office items'),
    ('Furniture',       'Office chairs, desks and storage'),
    ('Packaging',       'Boxes and shipping materials');

-- ---------------------------------------------------------------------
-- Suppliers
-- ---------------------------------------------------------------------
INSERT INTO suppliers (name, contact_name, email, phone, address) VALUES
    ('TechSource Distributors', 'Anita Rao',   'sales@techsource.example',   '+91-80-4000-1001', '12 Industrial Estate, Unit 4'),
    ('PaperTrail Supplies',     'Ravi Kumar',  'orders@papertrail.example',  '+91-80-4000-1002', '88 Market Road'),
    ('ComfortWorks Furniture',  'Meera Iyer',  'contact@comfortworks.example','+91-80-4000-1003', '5 Craftsman Lane'),
    ('BoxCraft Packaging',      'Vikram Shah', 'hello@boxcraft.example',     '+91-80-4000-1004', '301 Logistics Park');

-- ---------------------------------------------------------------------
-- Warehouses
-- ---------------------------------------------------------------------
INSERT INTO warehouses (code, name, location) VALUES
    ('WH-CEN', 'Central Warehouse', 'Main distribution centre'),
    ('WH-NTH', 'North Warehouse',   'Secondary storage facility');

-- ---------------------------------------------------------------------
-- Products (linked to category and supplier by name)
-- ---------------------------------------------------------------------
INSERT INTO products (sku, name, description, category_id, supplier_id, unit, cost_price, sale_price, reorder_level)
SELECT v.sku, v.name, v.description, c.id, s.id, v.unit, v.cost_price, v.sale_price, v.reorder_level
FROM (VALUES
    ('ELEC-001', 'Wireless Mouse',              '2.4 GHz wireless optical mouse',        'Electronics',     'TechSource Distributors', 'pcs',   450.00,   699.00,  20),
    ('ELEC-002', 'USB-C Charger 65W',           'Fast charger for laptops and phones',   'Electronics',     'TechSource Distributors', 'pcs',   900.00,  1499.00,  15),
    ('ELEC-003', 'Bluetooth Headphones',        'Over-ear, noise cancelling',            'Electronics',     'TechSource Distributors', 'pcs',  1800.00,  2799.00,  10),
    ('OFF-001',  'A4 Paper Ream (500 sheets)',  '75 GSM multipurpose paper',             'Office Supplies', 'PaperTrail Supplies',     'ream',  220.00,   320.00,  50),
    ('OFF-002',  'Ballpoint Pens (Box of 10)',  'Blue ink, medium tip',                  'Office Supplies', 'PaperTrail Supplies',     'box',    60.00,    99.00,  40),
    ('FURN-001', 'Ergonomic Office Chair',      'Adjustable lumbar support and armrests','Furniture',       'ComfortWorks Furniture',  'pcs',  5200.00,  7999.00,   5),
    ('FURN-002', 'Standing Desk',               'Electric height-adjustable desk',       'Furniture',       'ComfortWorks Furniture',  'pcs', 11000.00, 15999.00,   3),
    ('PACK-001', 'Cardboard Box (Medium)',      '40 x 30 x 30 cm, double wall',          'Packaging',       'BoxCraft Packaging',      'pcs',    25.00,    40.00, 100)
) AS v (sku, name, description, category_name, supplier_name, unit, cost_price, sale_price, reorder_level)
JOIN categories c ON c.name = v.category_name
JOIN suppliers  s ON s.name = v.supplier_name;

-- ---------------------------------------------------------------------
-- Stock movements (the ledger). days_ago spreads them over time so
-- date filters have something to work with later.
-- ---------------------------------------------------------------------
INSERT INTO stock_movements (product_id, warehouse_id, movement_type, quantity_change, reference, notes, created_at)
SELECT p.id, w.id, v.movement_type, v.quantity_change, v.reference, v.notes,
       now() - (v.days_ago * interval '1 day')
FROM (VALUES
    ('ELEC-001', 'WH-CEN', 'PURCHASE',    100, 'PO-1001', 'Opening stock',         30),
    ('ELEC-001', 'WH-CEN', 'SALE',        -35, 'SO-5001', NULL,                    12),
    ('ELEC-001', 'WH-NTH', 'PURCHASE',     40, 'PO-1002', 'Opening stock',         30),
    ('ELEC-002', 'WH-CEN', 'PURCHASE',     60, 'PO-1003', 'Opening stock',         28),
    ('ELEC-002', 'WH-CEN', 'SALE',        -20, 'SO-5002', NULL,                    10),
    ('ELEC-003', 'WH-CEN', 'PURCHASE',     25, 'PO-1004', 'Opening stock',         28),
    ('ELEC-003', 'WH-CEN', 'SALE',        -17, 'SO-5003', 'Bulk corporate order',   5),
    ('OFF-001',  'WH-CEN', 'PURCHASE',    200, 'PO-1005', 'Opening stock',         25),
    ('OFF-001',  'WH-NTH', 'PURCHASE',    120, 'PO-1006', 'Opening stock',         25),
    ('OFF-001',  'WH-NTH', 'SALE',        -30, 'SO-5004', NULL,                     8),
    ('OFF-002',  'WH-CEN', 'PURCHASE',    150, 'PO-1007', 'Opening stock',         22),
    ('FURN-001', 'WH-CEN', 'PURCHASE',     20, 'PO-1008', 'Opening stock',         20),
    ('FURN-001', 'WH-CEN', 'SALE',         -6, 'SO-5005', NULL,                     6),
    ('FURN-002', 'WH-NTH', 'PURCHASE',      5, 'PO-1009', 'Opening stock',         20),
    ('FURN-002', 'WH-NTH', 'SALE',         -3, 'SO-5006', NULL,                     3),
    ('PACK-001', 'WH-CEN', 'PURCHASE',    500, 'PO-1010', 'Opening stock',         18),
    ('PACK-001', 'WH-CEN', 'ADJUSTMENT',  -12, 'ADJ-001', 'Damaged in storage',     2)
) AS v (sku, warehouse_code, movement_type, quantity_change, reference, notes, days_ago)
JOIN products   p ON p.sku  = v.sku
JOIN warehouses w ON w.code = v.warehouse_code;

-- ---------------------------------------------------------------------
-- Stock levels: calculated from the ledger, so the two always agree
-- ---------------------------------------------------------------------
INSERT INTO stock_levels (product_id, warehouse_id, quantity)
SELECT product_id, warehouse_id, SUM(quantity_change)
FROM stock_movements
GROUP BY product_id, warehouse_id;

COMMIT;
