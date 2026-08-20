-- Bug [9] — aggiornaUrlRiga/aggiornaNotaRiga (supabase_adapter.js)
-- fallivano silenziosamente quando un dispositivo con "Aiuta il gruppo"
-- attivo scriveva su una carta di un altro utente: '.eq(owner_id, userId)'
-- filtrava sull'utente che ESEGUE l'azione, non sul proprietario reale.
-- Stesso identico schema già in uso per aggiorna_prezzo_controllo_gruppo
-- (verificato con pg_get_functiondef prima di scrivere questo fix).
-- GIÀ APPLICATO ED ESEGUITO IN PRODUZIONE in questa sessione — questo
-- file è solo la registrazione per il repo, non va rieseguito.

create or replace function public.aggiorna_url_controllo_gruppo(p_id uuid, p_url text)
 returns void
 language sql
 security definer
 set search_path to 'public'
as $function$
  update carte
  set url = p_url
  where id = p_id
    and stato = 'collezione';
$function$;

create or replace function public.aggiorna_nota_controllo_gruppo(p_id uuid, p_nota text)
 returns void
 language sql
 security definer
 set search_path to 'public'
as $function$
  update carte
  set note = p_nota
  where id = p_id
    and stato = 'collezione';
$function$;

-- ROLLBACK (sono funzioni nuove, non sostituiscono nulla di preesistente):
-- drop function if exists public.aggiorna_url_controllo_gruppo(uuid, text);
-- drop function if exists public.aggiorna_nota_controllo_gruppo(uuid, text);

-- Lato client: supabase_adapter.js, case 'aggiornaUrlRiga'/'aggiornaNotaRiga'
-- aggiornati per chiamare queste RPC al posto degli .update() diretti
-- (vedi file consegnato in questa sessione).

-- Verificato dal vivo il 20/08/2026: chiamata diretta su carta reale
-- (aggiornamento url/nota + lettura di conferma), poi ripristino dei
-- valori originali confermato.
