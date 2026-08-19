-- ============================================================
-- CardSync Pro — Fase 1: colonna metadata su user_media
-- (base per il nuovo slot 'card_back' — retro carta personalizzato)
-- Da eseguire DOPO 03_schema_ban_media_logs.sql, in Supabase:
-- Dashboard > SQL Editor > New query.
--
-- Nessuna modifica a RLS/policy/funzioni SECURITY DEFINER: la
-- colonna è nullable, ignorata dagli slot esistenti (binder_cover
-- continua a non usarla). Verificato prima di scrivere (vedi
-- ROADMAP_backcarte_integrazione_2026-08-19.md, sez.1): schema
-- reale di user_media non ha oggi nessuna colonna jsonb, RLS
-- slot-agnostica, nessun trigger presente.
-- ============================================================

alter table public.user_media
  add column if not exists metadata jsonb;
-- Uso previsto per lo slot 'card_back': memorizza il fieldState,
-- cioè le posizioni % dei 4 campi (nome/condizione/fumetto/prezzo)
-- disegnati sopra la sleeve a runtime. Slot esistenti (binder_cover)
-- la ignorano semplicemente (resta NULL per loro).

-- ============================================================
-- FINE — nessun altro passo in questa migration.
-- Prossimo passo (Fase 2): editor sleeve + upload dentro #binder,
-- lato client, nessun'altra modifica SQL necessaria per ora.
-- ============================================================
