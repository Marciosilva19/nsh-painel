-- =====================================================================
-- NSH · Painel de Gestão — estrutura da base de dados (versão 2)
-- Cola tudo no Supabase → SQL Editor → New query → Run.
-- Pode ser executado mais do que uma vez sem estragar nada.
-- =====================================================================

-- 1) Catálogo: produtos, variantes, preços, coleções e custos fixos.
--    Uma só linha ("main") com número de versão, para que duas pessoas
--    a editar ao mesmo tempo nunca apaguem as alterações uma da outra.
create table if not exists public.nsh_catalog (
  id          text primary key default 'main',
  data        jsonb not null,
  version     integer not null default 1,
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);

-- 2) Movimentos de stock: uma linha por entrada, venda, devolução,
--    amostra, perda ou ajuste. Nunca se apagam de verdade: "deleted"
--    marca os que foram anulados, para o histórico ficar completo.
create table if not exists public.nsh_movements (
  id          text primary key,
  move_date   date not null,
  product_id  text not null,
  variant_id  text not null,
  data        jsonb not null,
  deleted     boolean not null default false,
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  updated_at  timestamptz not null default now()
);
create index if not exists nsh_movements_updated_idx on public.nsh_movements (updated_at);
create index if not exists nsh_movements_product_idx on public.nsh_movements (product_id);
create index if not exists nsh_movements_date_idx    on public.nsh_movements (move_date);

-- 3) Reservas (pré-encomendas e lotes de revenda).
create table if not exists public.nsh_reservations (
  id          text primary key,
  status      text not null default 'open',
  product_id  text not null,
  data        jsonb not null,
  deleted     boolean not null default false,
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  updated_at  timestamptz not null default now()
);
create index if not exists nsh_reservations_updated_idx on public.nsh_reservations (updated_at);

-- 4) Hora de alteração sempre dada pelo servidor (a app usa-a para
--    sincronizar os telemóveis da equipa).
create or replace function public.nsh_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists nsh_catalog_touch on public.nsh_catalog;
create trigger nsh_catalog_touch before update on public.nsh_catalog
  for each row execute function public.nsh_touch();

drop trigger if exists nsh_movements_touch on public.nsh_movements;
create trigger nsh_movements_touch before update on public.nsh_movements
  for each row execute function public.nsh_touch();

drop trigger if exists nsh_reservations_touch on public.nsh_reservations;
create trigger nsh_reservations_touch before update on public.nsh_reservations
  for each row execute function public.nsh_touch();

-- 5) Segurança: só contas com sessão iniciada (as que crias em
--    Authentication → Users) leem e escrevem. Sem sessão: nada.
alter table public.nsh_catalog      enable row level security;
alter table public.nsh_movements    enable row level security;
alter table public.nsh_reservations enable row level security;

drop policy if exists "nsh_equipa" on public.nsh_catalog;
create policy "nsh_equipa" on public.nsh_catalog
  for all to authenticated using (true) with check (true);

drop policy if exists "nsh_equipa" on public.nsh_movements;
create policy "nsh_equipa" on public.nsh_movements
  for all to authenticated using (true) with check (true);

drop policy if exists "nsh_equipa" on public.nsh_reservations;
create policy "nsh_equipa" on public.nsh_reservations
  for all to authenticated using (true) with check (true);

revoke all on public.nsh_catalog, public.nsh_movements, public.nsh_reservations from anon;
grant select, insert, update, delete
  on public.nsh_catalog, public.nsh_movements, public.nsh_reservations
  to authenticated;
