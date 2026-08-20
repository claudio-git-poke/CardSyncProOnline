-- ============================================================
-- CardSync Pro — Fase 4-ter: cache-buster per le copie pubbliche
-- (risolve: viewer anonimo vede una versione vecchia della sleeve
-- dopo una nuova approvazione, per via della cache del browser sullo
-- stesso URL pubblico fisso 'carta/{userId}.png')
-- Da eseguire DOPO 07_schema_bucket_immaginivisibili.sql.
--
-- Non cambia i permessi né la logica di filtro della RPC esistente
-- (leggi_card_back_approvata), aggiunge solo una colonna in output:
-- reviewed_at, già presente su user_media, valorizzata dal dispatcher
-- admin_process_pending_request ad ogni approvazione. Il client la
-- userà come "?v=<reviewed_at>" nell'URL pubblico, per forzare il
-- browser a scaricare la versione nuova quando reviewed_at cambia.
-- ============================================================

create or replace function public.leggi_card_back_approvata(p_owner_id uuid)
returns table (storage_path text, source text, metadata jsonb, reviewed_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select storage_path, source, metadata, reviewed_at
  from user_media
  where user_id = p_owner_id
    and slot = 'card_back'
    and status = 'approved'
  limit 1;
$$;

grant execute on function public.leggi_card_back_approvata(uuid) to anon, authenticated;

-- ============================================================
-- ROLLBACK — torna alla versione precedente della RPC (senza
-- reviewed_at), se necessario:
--
-- create or replace function public.leggi_card_back_approvata(p_owner_id uuid)
-- returns table (storage_path text, source text, metadata jsonb)
-- language sql
-- security definer
-- set search_path = public
-- as $$
--   select storage_path, source, metadata
--   from user_media
--   where user_id = p_owner_id
--     and slot = 'card_back'
--     and status = 'approved'
--   limit 1;
-- $$;
-- grant execute on function public.leggi_card_back_approvata(uuid) to anon, authenticated;
-- ============================================================

-- ============================================================
-- VERIFICA DA FARE SUL DB REALE:
-- select * from leggi_card_back_approvata('3d99459f-12c4-40c7-b66e-271cf9adfd8b');
-- → deve restituire anche la colonna reviewed_at valorizzata (non null).
-- ============================================================
