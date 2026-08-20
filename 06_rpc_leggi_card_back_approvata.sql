-- ============================================================
-- CardSync Pro — Fase 4: RPC lettura card_back approvato
-- (necessaria per scambio.html/wishlist.html, viste pubbliche
-- senza sessione, stesso pattern già usato per leggi_sealed_condiviso
-- / leggi_scambio_condiviso / leggi_wishlist_condivisa)
-- Da eseguire DOPO 05_schema_default_assets_bucket.sql, in Supabase:
-- Dashboard > SQL Editor > New query.
--
-- NON crea nessuna policy pubblica su user_media (che resterebbe
-- leggibile anche in pending/rejected da chiunque): la RPC filtra
-- lei stessa, via SECURITY DEFINER, restituendo SOLO la riga
-- 'card_back' con status='approved' di uno specifico owner, o
-- nessuna riga se non esiste/non è approvata. index.html continua
-- a leggere la propria riga direttamente dalla tabella (utente
-- loggato, già coperto dalla RLS esistente) — questa RPC serve
-- SOLO al ramo "non-owner" (viewer anonimo).
-- ============================================================

create or replace function public.leggi_card_back_approvata(p_owner_id uuid)
returns table (storage_path text, source text, metadata jsonb)
language sql
security definer
set search_path = public
as $$
  select storage_path, source, metadata
  from user_media
  where user_id = p_owner_id
    and slot = 'card_back'
    and status = 'approved'
  limit 1;
$$;

grant execute on function public.leggi_card_back_approvata(uuid) to anon, authenticated;

-- ============================================================
-- ROLLBACK (se qualcosa non va, esegui questo per tornare indietro):
--
-- drop function if exists public.leggi_card_back_approvata(uuid);
-- ============================================================

-- ============================================================
-- VERIFICA DA FARE SUL DB REALE PRIMA DI PROCEDERE (non fidarti
-- solo di questa SQL):
-- 1) In SQL Editor, dopo l'esecuzione:
--    select * from leggi_card_back_approvata('<uuid di un utente
--    con card_back approvato>');
--    → deve restituire 1 riga.
-- 2) Stesso test con l'uuid di un utente SENZA card_back approvato
--    (pending, rejected, o nessuna riga) → deve restituire 0 righe.
-- ============================================================
