-- P5 local-only synthetic storefront fixtures. Never use as production data.
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, role, aud)
VALUES ('90000000-0000-4000-8000-000000000001',
  'p5-local-catalog-owner@rebuy.test', '{}'::jsonb, '{}'::jsonb,
  'authenticated', 'authenticated');

INSERT INTO public.organizations (id, organization_type, display_name, status, created_by)
VALUES
  ('90000000-0000-4000-8000-000000000101', 'merchant',
    'Aurora Mobile Lab', 'active', '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000102', 'merchant',
    'Circuit Commons', 'active', '90000000-0000-4000-8000-000000000001');

INSERT INTO public.stores (id, organization_id, organization_type,
  display_name, slug, status, public_visibility)
VALUES
  ('90000000-0000-4000-8000-000000000201',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    'Aurora Mobile', 'aurora-mobile-local', 'active', true),
  ('90000000-0000-4000-8000-000000000202',
    '90000000-0000-4000-8000-000000000102', 'merchant',
    'Circuit Commons', 'circuit-commons-local', 'active', true);

INSERT INTO public.products (id, organization_id, organization_type, category_id,
  product_kind, internal_name, status, created_by)
VALUES
  ('90000000-0000-4000-8000-000000000301',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '00000000-0000-4000-8000-000000000301', 'standard',
    'Local Modular Phone', 'active', '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000302',
    '90000000-0000-4000-8000-000000000102', 'merchant',
    '00000000-0000-4000-8000-000000000302', 'standard',
    'Local USB-C Charger', 'active', '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000303',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '00000000-0000-4000-8000-000000000303', 'secondhand',
    'Local Secondhand Phone', 'active', '90000000-0000-4000-8000-000000000001');

INSERT INTO public.product_variants (id, product_id, organization_id,
  organization_type, sku, unit_code, status)
VALUES
  ('90000000-0000-4000-8000-000000000401',
    '90000000-0000-4000-8000-000000000301',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    'SYN-SKU-LOCAL-PHONE', 'unit', 'active'),
  ('90000000-0000-4000-8000-000000000402',
    '90000000-0000-4000-8000-000000000302',
    '90000000-0000-4000-8000-000000000102', 'merchant',
    'SYN-SKU-LOCAL-CHARGER', 'unit', 'active'),
  ('90000000-0000-4000-8000-000000000403',
    '90000000-0000-4000-8000-000000000303',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    'SYN-SKU-LOCAL-USED', 'unit', 'active');

INSERT INTO public.listings (id, organization_id, organization_type, store_id,
  product_id, variant_id, product_kind, slug, title, summary, status, version,
  published_at, created_by)
VALUES
  ('90000000-0000-4000-8000-000000000501',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '90000000-0000-4000-8000-000000000201',
    '90000000-0000-4000-8000-000000000301',
    '90000000-0000-4000-8000-000000000401', 'standard',
    'local-modular-phone', '模块化智能手机', '可维修设计与清晰的合成库存状态。',
    'active', 1, pg_catalog.statement_timestamp(),
    '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000502',
    '90000000-0000-4000-8000-000000000102', 'merchant',
    '90000000-0000-4000-8000-000000000202',
    '90000000-0000-4000-8000-000000000302',
    '90000000-0000-4000-8000-000000000402', 'standard',
    'local-usb-c-charger', 'USB-C 快充套装', '适合手机与电脑的合成测试充电套装。',
    'active', 1, pg_catalog.statement_timestamp(),
    '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000503',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '90000000-0000-4000-8000-000000000201',
    '90000000-0000-4000-8000-000000000303',
    '90000000-0000-4000-8000-000000000403', 'secondhand',
    'local-secondhand-phone', '二手手机 · 良好', '已披露外观磨损、电池健康与合成序列引用。',
    'active', 1, pg_catalog.statement_timestamp(),
    '90000000-0000-4000-8000-000000000001');

INSERT INTO public.listing_prices (id, listing_id, organization_id,
  organization_type, store_id, audience, currency_code, unit_amount_cents,
  minimum_quantity, version, status, created_by)
VALUES
  ('90000000-0000-4000-8000-000000000601',
    '90000000-0000-4000-8000-000000000501',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '90000000-0000-4000-8000-000000000201', 'retail', 'EUR', 48900, 1, 1,
    'active', '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000602',
    '90000000-0000-4000-8000-000000000501',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '90000000-0000-4000-8000-000000000201', 'wholesale', 'EUR', 43900, 5, 1,
    'active', '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000603',
    '90000000-0000-4000-8000-000000000502',
    '90000000-0000-4000-8000-000000000102', 'merchant',
    '90000000-0000-4000-8000-000000000202', 'retail', 'EUR', 5900, 1, 1,
    'active', '90000000-0000-4000-8000-000000000001'),
  ('90000000-0000-4000-8000-000000000604',
    '90000000-0000-4000-8000-000000000503',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '90000000-0000-4000-8000-000000000201', 'retail', 'EUR', 21900, 1, 1,
    'active', '90000000-0000-4000-8000-000000000001');

INSERT INTO public.listing_price_tiers (id, price_id, listing_id,
  minimum_quantity, unit_amount_cents)
VALUES ('90000000-0000-4000-8000-000000000701',
  '90000000-0000-4000-8000-000000000602',
  '90000000-0000-4000-8000-000000000501', 10, 41900);

INSERT INTO public.inventory_levels (id, listing_id, organization_id,
  organization_type, store_id, on_hand, reserved, version)
VALUES
  ('90000000-0000-4000-8000-000000000801',
    '90000000-0000-4000-8000-000000000501',
    '90000000-0000-4000-8000-000000000101', 'merchant',
    '90000000-0000-4000-8000-000000000201', 24, 0, 1),
  ('90000000-0000-4000-8000-000000000802',
    '90000000-0000-4000-8000-000000000502',
    '90000000-0000-4000-8000-000000000102', 'merchant',
    '90000000-0000-4000-8000-000000000202', 40, 0, 1);

INSERT INTO public.secondhand_units (id, listing_id, product_kind,
  synthetic_serial_reference, condition_code, defect_code,
  battery_health_percent, warranty_days, status, version)
VALUES ('90000000-0000-4000-8000-000000000803',
  '90000000-0000-4000-8000-000000000503', 'secondhand',
  'SYN-UNIT-LOCAL-USED-001', 'good', 'cosmetic_wear', 87, 30,
  'available', 1);
