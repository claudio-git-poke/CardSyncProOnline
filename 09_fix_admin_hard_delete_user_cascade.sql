-- Bug [12] — admin_hard_delete_user falliva silenziosamente (rollback per
-- violazione FK) per qualunque utente con almeno una riga in una delle
-- tabelle collegate ad auth.users senza "on delete cascade". Verificato su
-- DB reale il 20/08/2026 (query su pg_constraint) prima di scrivere questo
-- fix — GIÀ APPLICATO ED ESEGUITO IN PRODUZIONE in questa sessione.
-- Questo file è solo la registrazione per il repo, non va rieseguito.

-- 1) Drop tabella deprecata (nessun riferimento client-side residuo,
--    confermato con grep su tutto il progetto). Rimuove anche 2 delle FK
--    bloccanti automaticamente.
drop table if exists public.zzz_deprecata_coda_carte_old_backup_20260818;

-- 2) Funzione aggiornata: dati personali cancellati esplicitamente (in
--    cascata verso binder_carte, già "on delete cascade" verso carte),
--    tabelle di log/audit/traccia di gruppo con riferimento azzerato
--    (SET NULL) invece di cancellazione, per preservare lo storico.
create or replace function public.admin_hard_delete_user(p_target uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;
  perform public.log_admin_action('hard_delete', p_target, null);

  -- Dati personali: cancellati con l'utente (binder_carte segue carte in cascade)
  delete from public.foto_carte where owner_id = p_target;
  delete from public.user_media where user_id = p_target;
  delete from public.location where owner_id = p_target;
  delete from public.preferenze_utente where owner_id = p_target;
  delete from public.wishlist where owner_id = p_target;
  delete from public.carte where owner_id = p_target;

  -- Log/audit e tracce di gruppo: riga preservata, riferimento azzerato
  update public.admin_audit_log set admin_id = null where admin_id = p_target;
  update public.activity_log set user_id = null where user_id = p_target;
  update public.pending_requests set user_id = null where user_id = p_target;
  update public.pending_requests set reviewed_by = null where reviewed_by = p_target;
  update public.user_media set reviewed_by = null where reviewed_by = p_target;
  update public.worker_presenza set user_id = null where user_id = p_target;
  update public.ordini set creato_da = null where creato_da = p_target;
  update public.ordini set preso_in_carico_da = null where preso_in_carico_da = p_target;
  update public.coda_wishlist set owner_id = null where owner_id = p_target;
  update public.coda_wishlist set claimed_by = null where claimed_by = p_target;
  update public.coda_lavoro set creato_da = null where creato_da = p_target;
  update public.coda_lavoro set claimed_by = null where claimed_by = p_target;

  delete from auth.users where id = p_target;
end;
$function$;

-- ROLLBACK (definizione originale, pre-fix):
-- create or replace function public.admin_hard_delete_user(p_target uuid)
--  returns void language plpgsql security definer set search_path to 'public'
-- as $function$
-- begin
--   if not public.is_admin() then raise exception 'Non autorizzato'; end if;
--   perform public.log_admin_action('hard_delete', p_target, null);
--   delete from auth.users where id = p_target;
-- end;
-- $function$;
-- Nota: il DROP TABLE non è rollback-abile (la tabella era essa stessa un
-- backup storico) — se serve tenerla, non eseguire lo step 1.

-- Verificato dal vivo il 20/08/2026: creazione, test con utente reale
-- (aggiornamento/lettura url e nota), ripristino valori originali confermato.
