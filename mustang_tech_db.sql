-- Таблица регионов
create table regions (
    region_id varchar primary key,
    region_name varchar not null unique,
    vet_status varchar not null,
    is_risk_zone boolean default false
);

-- Таблица сырья
create table raw_material (
    material_id varchar primary key,
    material_name varchar not null unique,
    unit varchar not null,
    category varchar not null,
    safety_stock decimal not null
);

-- Таблица поставщиков
create table supplier (
    supplier_id varchar primary key,
    supplier_name varchar not null,
    region_id varchar not null references regions(region_id),
    phone varchar check (phone ~ '^\+7\(\d{3}\)\d{3}-\d{2}-\d{2}$'),
    reliability_rating decimal
);

-- Таблица заказов на закупку
create table purchase_order (
    purchase_order_id varchar primary key,
    supplier_id varchar not null references supplier(supplier_id),
    material_id varchar not null references raw_material(material_id),
    order_date date not null,
    price_rub decimal not null,
    quantity decimal not null,
    status varchar not null
);

-- Таблица готовой продукции
create table finished_good (
    product_id varchar primary key,
    product_name varchar not null unique,
    product_type varchar not null,
    animal_type varchar not null,
    base_price decimal not null,
    min_margin_pct decimal not null default 5.0,
    product_code varchar check (product_code ~ '^(ZCM|PRM)-\d{4}$')
);

-- Таблица спецификаций
create table specification (
    specification_id varchar primary key,
    product_id varchar not null references finished_good(product_id),
    material_id varchar not null references raw_material(material_id),
    quantity_per_unit decimal not null
);

-- Таблица клиентов
create table customer (
    customer_id varchar primary key,
    customer_name varchar not null,
    region_id varchar not null references regions(region_id),
    contact_phone varchar check (contact_phone ~ '^\+7\(\d{3}\)\d{3}-\d{2}-\d{2}$')
);

-- Таблица заказов покупателей
create table sales_order (
    sales_order_id varchar primary key,
    customer_id varchar not null references customer(customer_id),
    product_id varchar not null references finished_good(product_id),
    order_date date not null,
    quantity decimal not null,
    is_tender boolean default false,
    status varchar not null,
    rejection_reason varchar  
);

-- Таблица планов производства
create table production_plan (
    plan_id varchar primary key,
    product_id varchar not null references finished_good(product_id),
    start_period date not null,
    end_period date not null,
    planned_quantity decimal not null,
    status varchar not null,
    version integer default 1,
    rejection_reason varchar
);

-- Таблица внешних событий и рисков
create table external_event (
    event_id serial primary key,
    region_id varchar not null references regions(region_id),
    purchase_order_id varchar references purchase_order(purchase_order_id),
    event_name varchar not null,
    severity_level varchar not null,
    start_date date not null,
    end_date date,
    document_attachments varchar[],
    event_details jsonb
);

-- Наполнение данными

insert into regions (region_id, region_name, vet_status, is_risk_zone) values
('belgobl', 'Белгородская область', 'Карантин', true),
('mosobl', 'Московская область', 'Благополучный', false);

insert into raw_material values 
('lys_hcl', 'L-Лизин моногидрохлорид', 'кг', 'Аминокислоты', 5000.0);

insert into supplier values 
('belbio_sup', 'ООО БелБио Снаб', 'belgobl', '+7(472)111-22-33', 4.8),
('moskorm', 'АО МосКорм', 'mosobl', '+7(495)777-88-99', 4.2);

insert into purchase_order values 
('po_001', 'belbio_sup', 'lys_hcl', '2026-05-15', 195.00, 10000.0, 'Утвержден'),
('po_002', 'moskorm', 'lys_hcl', '2026-05-16', 205.00, 5000.0, 'Утвержден');

insert into finished_good values 
('mustang_milk_16', 'ЗЦМ Мустанг Милк 16%', 'ЗЦМ', 'КРС', 120.00, 15.0, 'ZCM-1160'),
('premix_krs_opt', 'Премикс КРС Оптима', 'Премикс', 'КРС', 250.00, 18.0, 'PRM-2024');

insert into customer values 
('cherkizovo', 'ЗАО Черкизово', 'belgobl', '+7(999)123-45-67');

insert into sales_order values 
('so_001', 'cherkizovo', 'mustang_milk_16', '2026-05-20', 25000.0, true, 'Выигран', null),
('so_002', 'cherkizovo', 'premix_krs_opt', '2026-05-22', 5000.0, false, 'Отменен', 'Отказ от тендера из-за логистики');

insert into external_event (region_id, purchase_order_id, event_name, severity_level, start_date, end_date, document_attachments, event_details) values
('belgobl', 'po_001', 'Карантин: Вспышка АЧС', 'Критический', '2026-05-10', null, array['/docs/prikaz_12.pdf', '/docs/vet_limit.png'], null),
('mosobl', null, 'Анализ рынка аминокислот', 'Низкий', '2026-05-01', '2026-05-15', array['/docs/monitoring_may.pdf'], null);

update external_event 
set event_details = '[
    {
        "компонент": "L-Лизин",
        "конкурент": "ООО БелБио",
        "цена_руб": 210.00,
        "тенденция": "Дефицит"
    },
    {
        "компонент": "Витамин Е",
        "конкурент": "АгроСнаб",
        "цена_руб": 850.00,
        "тенденция": "Стабильно"
    }
]'::jsonb
where event_id = 1;

update external_event 
set event_details = '[
    {
        "компонент": "L-Лизин",
        "конкурент": "Трейд-Корм",
        "цена_руб": 195.50,
        "тенденция": "Дефицит"
    }
]'::jsonb
where event_id = 2;

select * from public.customer

select * from public.finished_good


-- Представления
-- Риски по заказам на покупку
create view active_risks_on_purchases as
select 
po.purchase_order_id,
s.supplier_name,
rm.material_name,
po.quantity,
po.price_rub,
po.order_date,
e.event_id,
e.event_name,
e.severity_level,
e.start_date,
e.end_date,
r.region_name,
r.vet_status
from purchase_order po
join supplier s on po.supplier_id = s.supplier_id
join regions r on s.region_id = r.region_id
join external_event e on e.region_id = r.region_id
join raw_material rm on po.material_id = rm.material_id
where po.status = 'Утвержден'
  and e.start_date <= CURRENT_DATE
  and (e.end_date is null or e.end_date >= CURRENT_DATE)
order by e.severity_level desc, po.order_date desc;

select * from active_risks_on_purchases

-- активные риски
create view active_risks as
select 
event_id,
event_name,
severity_level,
region_id,
start_date,
end_date
from external_event
where start_date <= current_date 
  and (end_date is null or end_date >= current_date);

select * from active_risks


-- поставщики с рисками
create view suppliers_at_risk as
select 
s.supplier_id,
s.supplier_name,
r.region_name,
e.event_name,
e.severity_level
from supplier s
join regions r on s.region_id = r.region_id
join external_event e on e.region_id = r.region_id
where e.start_date <= current_date  and (e.end_date is null or e.end_date >= current_date);

select * from suppliers_at_risk

-- отмененные заказы
create view cancelled_orders as
select 
so.sales_order_id,
c.customer_name,
fg.product_name,
so.quantity,
so.quantity * fg.base_price as lost_amount,
so.rejection_reason
from sales_order so
join customer c on so.customer_id = c.customer_id
join finished_good fg on so.product_id = fg.product_id
where so.status in ('Отменен', 'Проигран');

select * from cancelled_orders

--Функции
-- Сумма отмененных заказов по клиенту
create or replace function get_cancelled_sales_amount(p_customer_id varchar)
returns decimal as $$
select coalesce(sum(so.quantity * fg.base_price), 0)
from sales_order so
join finished_good fg on so.product_id = fg.product_id
where so.customer_id = p_customer_id
  and so.status in ('Отменен', 'Проигран')
$$ language sql;

select get_cancelled_sales_amount('cherkizovo');

-- Альтернативные поставщики
create or replace function get_alternative_suppliers(p_material_id varchar, p_exclude_supplier_id varchar)
returns table (supplier_name varchar, price_rub decimal, reliability_rating decimal) 
as $$
begin
return query
select 
s.supplier_name,
po.price_rub,
s.reliability_rating
from purchase_order po
join supplier s on po.supplier_id = s.supplier_id
where po.material_id = p_material_id and s.supplier_id != p_exclude_supplier_id and po.status = 'Утвержден'
order by s.reliability_rating desc, po.price_rub asc;
end;
$$ language plpgsql;

select * from get_alternative_suppliers('lys_hcl', 'belbio_sup');

-- Цена на продукт с маржой
create or replace function get_product_price_with_margin(p_product_name varchar)
returns table (product_name_out varchar, final_price decimal) 
as $$
select product_name, (base_price + base_price * min_margin_pct / 100) 
from finished_good
where product_name = p_product_name
$$ language sql;

select * from get_product_price_with_margin('ЗЦМ Мустанг Милк 16%');

-- Триггеры
-- Черновик для новых заказов
create or replace function set_draft_status()
returns trigger as $$
begin 
if new.status is null then new.status := 'Черновик';
end if;
return new;
end;
$$ language plpgsql;

create trigger trg_set_draft_status 
before insert on purchase_order 
for each row execute function set_draft_status();

insert into purchase_order (purchase_order_id, supplier_id, material_id, order_date, price_rub, quantity)
values ('po_003', 'moskorm', 'lys_hcl', '2026-05-25', 200.00, 3000.00);

select * from purchase_order where purchase_order_id = 'po_003';


-- Дата начала не раньше сегодняшней
create or replace function check_event_start_date()
returns trigger as $$
begin
if new.start_date < current_date then
raise exception 'Дата начала события не может быть раньше текущей даты';
end if;
return new;
end;
$$ language plpgsql;

create trigger trg_check_event_start_date 
before insert on external_event 
for each row execute function check_event_start_date();

insert into external_event (region_id, event_name, severity_level, start_date)
values ('mosobl', 'Карантин', 'Низкий', '2020-01-01');


-- Риск для региона
create or replace function set_region_risk_zone()
returns trigger 
as $$
begin
if new.severity_level = 'Критический' then
update regions 
set is_risk_zone = true, 
vet_status = 'Зона риска'
where region_id = new.region_id;
end if;
return new;
end;
$$ language plpgsql;


create trigger trg_set_region_risk_zone
after insert on external_event
for each row execute function set_region_risk_zone();

insert into external_event (region_id, event_name, severity_level, start_date)
values ('mosobl', 'Вспышка заболевания', 'Критический', current_date);

select * from regions where region_id = 'mosobl';


-- Оконные функции
--Средняя цена у поставщиков
select s.supplier_name, rm.material_name, po.price_rub,
round(avg(po.price_rub) over (partition by rm.material_id)) as avg_market_price
from purchase_order po
join supplier s on po.supplier_id = s.supplier_id
join raw_material rm on po.material_id = rm.material_id
where po.status = 'Утвержден'
order by rm.material_name, po.price_rub;

--Отказы клиентов
select c.customer_name, so.order_date, fg.product_name, so.quantity, so.rejection_reason,
row_number() over (partition by c.customer_id order by so.order_date) as cancel_number
from sales_order so
join customer c on so.customer_id = c.customer_id
join finished_good fg on so.product_id = fg.product_id
where so.status in ('Отменен', 'Проигран')
order by c.customer_name, so.order_date;

