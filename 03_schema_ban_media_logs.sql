-- ============================================================
-- CardSync Pro — Ban/Delete utenti, log admin, log attività,
-- media per-utente (v3)
-- Da eseguire DOPO 02_schema_admin.sql, in Supabase:
-- Dashboard > SQL Editor > New query.
--
-- Verificato prima di scrivere (query dirette di Claudio,
-- 19/08/2026): auth.users.encrypted_password è character varying,
-- estensione pgcrypto già attiva, auth.sessions e
-- auth.refresh_tokens hanno colonna user_id diretta.
-- ============================================================

-- ── 1) BAN SU PROFILES ──────────────────────────────────────────
alter table public.profiles
  add column if not exists banned_until timestamptz,
  add column if not exists ban_reason text;
-- banned_until NULL = non bannato · data futura = ban temporaneo
-- 'infinity' = perma-ban · reversibile in qualunque momento con
-- un update (nessun bisogno di cron: la scadenza è "pigra", basta
-- confrontare con now() ovunque venga controllato lo stato).


-- ── 2) LOG AZIONI ADMIN ──────────────────────────────────────────
create table if not exists public.admin_audit_log (
  id uuid default gen_random_uuid() primary key,
  admin_id uuid references auth.users(id) not null,
  action text not null,              -- es: 'ban','unban','soft_delete',
                                      -- 'restore','hard_delete',
                                      -- 'reset_password','revoke_sessions',
                                      -- 'role_change','request_approved',
                                      -- 'request_rejected'
  target_user_id uuid,               -- niente FK con cascade: vogliamo
                                      -- tenere il log anche dopo un
                                      -- hard delete dell'utente target
  details jsonb,
  created_at timestamptz default now()
);

alter table public.admin_audit_log enable row level security;

create policy "solo admin legge il log admin"
on public.admin_audit_log for select
using (public.is_admin());
-- niente policy insert/update/delete per client: si scrive SOLO dalle
-- funzioni SECURITY DEFINER sotto, mai da query dirette del browser.

create or replace function public.log_admin_action(
  p_action text, p_target uuid, p_details jsonb default null
) returns void as $$
begin
  insert into public.admin_audit_log (admin_id, action, target_user_id, details)
  values (auth.uid(), p_action, p_target, p_details);
end;
$$ language plpgsql security definer set search_path = public;


-- ── 3) LOG ATTIVITÀ UTENTE (sito + estensione) ───────────────────
-- Tabella e lettura pronte ora. Chi SCRIVE dentro (istruzioni nelle
-- pagine del sito e nei file dell'estensione) è lavoro rimandato,
-- vedi obiettivi_prossima_chat.txt — per ora resta vuota.
create table if not exists public.activity_log (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  source text not null check (source in ('sito','estensione')),
  action text not null,
  details jsonb,
  created_at timestamptz default now()
);

alter table public.activity_log enable row level security;

create policy "utente crea le proprie voci di log"
on public.activity_log for insert
with check (auth.uid() = user_id);

create policy "admin legge tutto il log attività"
on public.activity_log for select
using (public.is_admin());

create index if not exists activity_log_user_idx
  on public.activity_log (user_id, created_at desc);


-- ── 4) MEDIA PER-UTENTE (foto caricate, uno slot = un file) ──────
create table if not exists public.user_media (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  slot text not null,                -- es: 'card_back'. Testo libero
                                      -- (non enum) per aggiungere slot
                                      -- futuri ('binder_cover', ecc.)
                                      -- senza toccare lo schema.
  storage_path text not null,        -- '{user_id}/{slot}' nel bucket
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_note text,
  created_at timestamptz default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  unique (user_id, slot)             -- una seconda foto sullo stesso
                                      -- slot sovrascrive la riga (upsert)
);

alter table public.user_media enable row level security;

create policy "utente vede i propri media"
on public.user_media for select
using (auth.uid() = user_id);

create policy "utente crea/aggiorna i propri media"
on public.user_media for insert
with check (auth.uid() = user_id);

create policy "utente aggiorna i propri media in pending"
on public.user_media for update
using (auth.uid() = user_id and status = 'pending')
with check (auth.uid() = user_id);

create policy "admin vede tutti i media"
on public.user_media for select
using (public.is_admin());

create policy "admin aggiorna tutti i media"
on public.user_media for update
using (public.is_admin());

-- Bucket storage privato per i file (niente accesso pubblico diretto,
-- tutto passa da policy). Crea solo se non esiste già.
insert into storage.buckets (id, name, public)
select 'user-media', 'user-media', false
where not exists (select 1 from storage.buckets where id = 'user-media');

-- Percorso atteso: user-media/{user_id}/{slot}
-- storage.foldername(name) spacchetta il path in segmenti di cartella.

create policy "utente legge i propri file"
on storage.objects for select
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "utente carica i propri file"
on storage.objects for insert
with check (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "utente sostituisce i propri file"
on storage.objects for update
using (bucket_id = 'user-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "admin legge tutti i file"
on storage.objects for select
using (bucket_id = 'user-media' and public.is_admin());

-- ASSUNZIONE (da confermare — vedi messaggio in chat): una volta
-- approvata, la foto diventa visibile agli ALTRI utenti autenticati
-- del gruppo (non al pubblico di internet). Se invece deve restare
-- visibile solo al proprietario, cancella la policy seguente.
create policy "utenti autenticati leggono i file approvati altrui"
on storage.objects for select
using (
  bucket_id = 'user-media'
  and exists (
    select 1 from public.user_media m
    where m.storage_path = storage.objects.name
      and m.status = 'approved'
  )
);


-- ── 5) FUNZIONI ADMIN (ban / delete / reset password / revoca) ───
-- Tutte: SECURITY DEFINER, controllano is_admin() internamente,
-- scrivono da sole nel log admin. Il client non può bypassarle
-- perché non ha grant diretti di UPDATE/DELETE su auth.*.

-- Revoca istantanea di tutte le sessioni attive di un utente
-- (uccide i refresh token: al prossimo refresh l'utente è sloggato;
-- l'access token già in mano resta valido fino alla sua naturale
-- scadenza, tipicamente entro un'ora — vedi nota in chat).
create or replace function public.admin_revoke_sessions(p_target uuid)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  delete from auth.refresh_tokens where user_id = p_target::text;
  delete from auth.sessions where user_id = p_target;

  perform public.log_admin_action('revoke_sessions', p_target, null);
end;
$$ language plpgsql security definer set search_path = public;

-- Ban temporaneo o permanente (p_until = 'infinity' per perma-ban).
-- Instant: revoca anche le sessioni attive.
create or replace function public.admin_ban_user(p_target uuid, p_until timestamptz, p_reason text default null)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  update public.profiles set banned_until = p_until, ban_reason = p_reason where id = p_target;
  delete from auth.refresh_tokens where user_id = p_target::text;
  delete from auth.sessions where user_id = p_target;

  perform public.log_admin_action('ban', p_target, jsonb_build_object('until', p_until, 'reason', p_reason));
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.admin_unban_user(p_target uuid)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  update public.profiles set banned_until = null, ban_reason = null where id = p_target;
  perform public.log_admin_action('unban', p_target, null);
end;
$$ language plpgsql security definer set search_path = public;

-- Soft delete: nasconde/blocca l'account, revoca subito le sessioni.
-- Reversibile con admin_restore_user.
create or replace function public.admin_soft_delete_user(p_target uuid)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  update public.profiles set deleted_at = now() where id = p_target;
  delete from auth.refresh_tokens where user_id = p_target::text;
  delete from auth.sessions where user_id = p_target;

  perform public.log_admin_action('soft_delete', p_target, null);
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.admin_restore_user(p_target uuid)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  update public.profiles set deleted_at = null where id = p_target;
  perform public.log_admin_action('restore', p_target, null);
end;
$$ language plpgsql security definer set search_path = public;

-- HARD DELETE — irreversibile. Cancella auth.users, che a cascata
-- (FK "on delete cascade" già in profiles) elimina anche il profilo.
-- Utile solo per pulizia account di test.
create or replace function public.admin_hard_delete_user(p_target uuid)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;

  perform public.log_admin_action('hard_delete', p_target, null);
  delete from auth.users where id = p_target;
end;
$$ language plpgsql security definer set search_path = public;

-- Reset password manuale: l'admin genera la nuova password (client-side,
-- nome pokemon minuscolo) e questa funzione la applica + revoca le
-- sessioni vecchie (la password cambia, i login già attivi con quella
-- vecchia non devono restare validi).
create or replace function public.admin_reset_password(p_target uuid, p_new_password text)
returns void as $$
begin
  if not public.is_admin() then
    raise exception 'Non autorizzato';
  end if;
  if length(p_new_password) < 6 then
    raise exception 'Password troppo corta';
  end if;

  update auth.users
  set encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = p_target;

  delete from auth.refresh_tokens where user_id = p_target::text;
  delete from auth.sessions where user_id = p_target;

  perform public.log_admin_action('reset_password', p_target, null);
end;
$$ language plpgsql security definer set search_path = public;


-- ── 6) AUTH HOOK — NON UTILIZZABILE sul piano Supabase attuale ───
-- [SOSPESO, 19/08/2026] Claudio ha verificato dal vivo che "Password
-- verification attempt" non è disponibile sul suo progetto (piano
-- Free). La funzione qui sotto resta pronta e corretta (contratto
-- ufficiale Supabase verificato su doc: input {user_id, valid},
-- output {decision, message, should_logout_user}) per il giorno in
-- cui si passasse a un piano che la sblocca — ma OGGI non è
-- collegabile a nessun hook. Il blocco del ban oggi passa da:
-- (a) revoca sessione immediata (funzioni sez.5) + (b) controllo
-- lato client subito dopo login (admin.html aggiornato) + (c) RLS
-- sulle tabelle dati, NON ancora estese in questa sessione (vedi
-- Domanda #11 nel file di stato).
create or replace function public.handle_password_verification_attempt(event jsonb)
returns jsonb as $$
declare
  v_user_id uuid;
  v_banned_until timestamptz;
  v_deleted_at timestamptz;
begin
  if (event->>'valid')::boolean is not true then
    return jsonb_build_object('decision', 'continue');
  end if;

  v_user_id := (event->>'user_id')::uuid;

  select banned_until, deleted_at into v_banned_until, v_deleted_at
  from public.profiles
  where id = v_user_id;

  if v_deleted_at is not null then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Account disattivato. Contatta un amministratore.',
      'should_logout_user', true
    );
  end if;

  if v_banned_until is not null and v_banned_until > now() then
    return jsonb_build_object(
      'decision', 'reject',
      'message', 'Account sospeso fino al ' || to_char(v_banned_until, 'DD/MM/YYYY HH24:MI') || '.',
      'should_logout_user', true
    );
  end if;

  return jsonb_build_object('decision', 'continue');
end;
$$ language plpgsql security definer set search_path = public;
-- Nessun grant necessario: la funzione resta "orfana" (nessun hook la
-- chiama) finché non si sblocca la sezione su Supabase o si passa a
-- un'Edge Function come tramite del login (opzione B discussa in chat,
-- non implementata).

-- ============================================================
-- 7) ESTENSIONE pending_requests.type — aggiunge username_change
-- ============================================================
alter table public.pending_requests drop constraint if exists pending_requests_type_check;
alter table public.pending_requests add constraint pending_requests_type_check
  check (type in ('photo_upload','password_reset','username_change','other'));

-- ============================================================
-- 8) NESSUN PASSO MANUALE SU AUTH HOOKS — non disponibile sul piano
--    Free (verificato da Claudio, 19/08/2026). Il ban oggi funziona
--    così: appena bannato, admin_ban_user revoca la sessione attiva
--    (l'utente viene sloggato entro il refresh, di norma <1h); al
--    prossimo tentativo di login, admin.html blocca subito
--    (controllo aggiunto lato client). Per bloccare login/uso anche
--    a chi chiama le API direttamente (bot), serve estendere le RLS
--    delle tabelle dati — non fatto qui, vedi Domanda #11.
-- ============================================================
