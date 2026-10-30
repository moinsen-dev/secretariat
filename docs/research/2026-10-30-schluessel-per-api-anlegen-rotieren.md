# Schlüssel per Anbieter-API anlegen, begrenzen, listen, widerrufen

Stand: 2026-10-30 (alle Seiten an diesem Tag abgerufen, außer wo vermerkt). Kontext: `docs/vision-2.0.md`.
Methode: nur Primärquellen (offizielle Docs, API-Referenzen). Was dort nicht steht, ist als **unsicher** oder **Vermutung** markiert. Einige Seiten (Cloudflare, GitHub) kamen über ein Abruf-Werkzeug, das den Text zusammenfasst; Pfade und Feldnamen dort sind gegen eine zweite Fundstelle gegengeprüft, der Wortlaut nicht 1:1.

## 1. Frage

Welche Anbieter erlauben per offizieller Verwaltungs-API (a) einen neuen Schlüssel anzulegen, (b) Rechte/Scopes zu setzen, (c) Ablauf zu setzen, (d) Schlüssel zu listen, (e) zu widerrufen oder zu rotieren, und welches Bootstrap-Credential braucht man dafür?

## 2. Antwort in drei Sätzen

Vollständig per API (anlegen, begrenzen, listen, widerrufen) gehen Cloudflare, OpenAI (nur Service-Account-Schlüssel), Supabase, Resend, Mailgun, Vercel, AWS und Google Cloud; GitHub liefert nur kurzlebige App-Installation-Tokens (1 Stunde), keine PATs. Gar nicht per API anlegbar sind Anthropic (ausdrücklich „nein“, nur lesen, umbenennen, deaktivieren), Stripe, Apple App Store Connect, Lemon Squeezy und Hetzner, dort bleibt der heutige Weg (Zwischenablage, Import). Jeder Adapter braucht ein vom Menschen einmal in der Anbieter-Oberfläche erzeugtes Bootstrap-Credential; die beste Eingrenzung bieten Cloudflare (Token nur mit „Account API Tokens Write“, IP-Filter und TTL) und Supabase (feingranularer PAT nur für „API Keys“), die schlechteste Resend (der Verwalter ist ein `full_access`-Schlüssel).

## 3. Tabelle

Legende: ja / nein / teilweise / unsicher (mit Kurzbegründung). „Ablauf“ = Ablaufdatum beim Anlegen setzbar.

| Anbieter | anlegen | Rechte | Ablauf | listen | widerrufen | Bootstrap-Credential |
|---|---|---|---|---|---|---|
| Cloudflare (Account-Token) | ja, `POST /accounts/{id}/tokens` | ja (Policies, Permission-Groups, Ressourcen, IP-Bedingung) | ja (`expires_on`, `not_before`) | ja, `GET /accounts/{id}/tokens` | ja, `DELETE …/{token_id}`; Roll `PUT …/{token_id}/value` | Token mit „Account API Tokens Write“, einmal im Dashboard erzeugt |
| GitHub PAT (classic, fine-grained) | nein, nur UI (kein API-Weg dokumentiert) | – | – | nein (Org-Owner: nur über GitHub-App-Token, unsicher im Detail) | teilweise: `POST /credentials/revoke` ohne Auth für geleakte Token | – |
| GitHub App (Installation Token) | ja, `POST /app/installations/{id}/access_tokens` | ja (Repos und Permissions als Teilmenge) | nein, fest 1 Stunde | teilweise: Installationen ja (`GET /app/installations`), ausgegebene Tokens unsicher | ja, `DELETE /installation/token` (nur mit dem Token selbst) | App-Private-Key (PEM) zum JWT-Signieren; PEM nur über UI oder Manifest-Flow |
| OpenAI Service-Account-Key | ja, `POST …/service_accounts/{id}/api_keys` | teilweise (Feld `scopes` vorhanden, Werte unsicher) | ja (`expires_in_seconds`, max. 1 Jahr) | ja (Projekt-Keys listen) | ja (Projekt-Key löschen) | Admin-Key (nur Org-Owner, im UI erzeugt) |
| OpenAI normaler Projekt-Key | nein, nur UI | – (Update-Endpunkt existiert) | – | ja | ja | Admin-Key |
| OpenAI Admin-Key | ja, `POST /organization/admin_api_keys` | unsicher (Body nur `name`, `expires_in_seconds`) | ja | ja | ja | bestehender Admin-Key |
| Anthropic | **nein** („No. You create API keys in the Claude Console“) | – | nur im Console-Dialog (3 Std. bis „Never“) | ja, `GET /v1/organizations/api_keys` | teilweise: Status `inactive`/`archived` per `POST …/{id}` | Admin-Key oder OAuth `org:admin`; Service-Account-Endpunkte nur OAuth |
| Google API Key (inkl. Gemini) | ja, `POST apikeys.googleapis.com/v2/projects/*/locations/global/keys` (Operation) | ja (`apiTargets`, Client-Restriktionen; Gemini-Key braucht Service-Account-Bindung) | nein (kein Feld in der Ressource) | ja (`keys.list`) | ja (`keys.delete`, 30 Tage `undelete`) | Nutzer-/Service-Account-Credential mit `apikeys.keys.create` |
| Google Service-Account-Key | ja, `POST iam.googleapis.com/v1/projects/*/serviceAccounts/*/keys` | nein am Key (Rechte hängen am Service Account) | teilweise (nur per Org-Policy, nicht pro Aufruf) | ja | ja (`keys.delete`, vorher `disable`) | Credential mit IAM-Key-Admin; Org-Policy sperrt Anlegen standardmäßig |
| AWS IAM Access Key | ja, `CreateAccessKey` | nein am Key (erbt die Policies des IAM-Users) | unsicher (in der API-Referenz kein Ablaufparameter) | ja, `ListAccessKeys` | ja, `DeleteAccessKey`, `UpdateAccessKey` (Inactive) | IAM-Credential mit `iam:CreateAccessKey` |
| Supabase (Projekt-Keys) | ja, `POST /v1/projects/{ref}/api-keys` | teilweise (`type`, `secret_jwt_template`) | nein (kein Feld) | ja, `GET /v1/projects/{ref}/api-keys` | ja, `DELETE …/{id}` (mit `was_compromised`, `reason`) | Scoped PAT (nur „API Keys“ Read-write) oder OAuth `secrets:write` |
| Resend | ja, `POST /api-keys` | teilweise (`full_access` / `sending_access`, optional Domain) | nein (kein Feld) | ja, `GET /api-keys` | ja, `DELETE /api-keys/{id}` | `full_access`-API-Key |
| Stripe (Restricted Key) | nein, nur Dashboard (mit 2FA) | – | – | nein | nein per API (Dashboard: Expire/Rotate) | – |
| Apple App Store Connect | nein, nur UI (Admin; API-Zugang beantragt der Account Holder) | – | – | nein | nein, nur UI | – |
| Lemon Squeezy | nein, nur UI (Settings » API) | – | – | nein | nein | – |
| Hetzner Cloud | nein, nur Console (Security » API tokens) | – | – | nein | nein | – |
| Vercel | ja, `POST /v3/user/tokens` | teilweise (Team/Projekt-Scope, keine Rechte-Matrix) | ja (`expiresAt`) | ja, `GET /v6/user/tokens` | ja, `DELETE /v3/user/tokens/{id}` | Full-Account-Token (Team-/Projekt-Tokens dürfen keine Tokens anlegen) |
| Mailgun | ja, `POST /v1/keys` | ja (`role`, `kind`, `domain_name`) | ja (`expiration` in Sekunden) | ja, `GET /v1/keys` | ja, `DELETE /v1/keys/{id}` | Key mit Rolle `admin` (RBAC-Rollen erst ab Foundation-Tarif) |
| Postmark | unsicher: Server anlegen liefert Token (Account-API-Token) | – | – | unsicher | unsicher | Account-API-Token (nur Account-Owner) |

Kosten: in keiner abgerufenen Doku ist die Verwaltungs-API kostenpflichtig oder gesondert abgerechnet vermerkt (nicht überall ausdrücklich verneint).

## 4. Belege je Anbieter

### 4.1 Cloudflare

Quellen (alle abgerufen 2026-10-30):
- [C1] https://developers.cloudflare.com/api/resources/accounts/subresources/tokens/methods/create/ — `POST /accounts/{account_id}/tokens`; Body: `name` (max. 120), `policies[]` (`effect`, `permission_groups[].id`, `resources`), `condition.request_ip.in/not_in`, `expires_on`, `not_before`; Antwort enthält `value` (40 bis 80 Zeichen), `id`, `status`; verlangt „Account API Tokens Write“.
- [C2] https://developers.cloudflare.com/api/resources/accounts/subresources/tokens/ — Methodenliste: `GET /accounts/{id}/tokens` (list), `GET …/{token_id}`, `PUT …/{token_id}` (update), `DELETE …/{token_id}`, `GET …/tokens/verify`, `PUT …/{token_id}/value` (Roll), `GET …/tokens/permission_groups`. Die Seite nennt je Methode kein Berechtigungserfordernis.
- [C3] https://developers.cloudflare.com/fundamentals/api/how-to/create-via-api/ — Erstellen über `/accounts/{id}/tokens` (Account-Token) oder `/user/tokens` (User-Token); es braucht ein im Dashboard erzeugtes Start-Token mit Berechtigung zum Anlegen weiterer Tokens; Cloudflare rät, dem Start-Token nichts anderes zu geben und es mit IP-Filter oder TTL zu begrenzen; Permission-Groups über ihre `id` ansprechen, nicht über den Namen.
- [C4] https://developers.cloudflare.com/fundamentals/api/get-started/create-token/ — „The token secret is only shown once.“
- [C5] https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/ — Mitglied braucht „API Token Provisioning“ oder Super Administrator; vergebbar ist nur eine Teilmenge der eigenen Rechte.
- [C6] https://developers.cloudflare.com/fundamentals/api/how-to/roll-token/ — Dashboard-Roll „invalidiert das vorige Token“; ob sofort oder verzögert, steht nicht dort.
- [C7] https://developers.cloudflare.com/fundamentals/api/reference/limits/ — 1.200 Anfragen je 5 Minuten je Nutzer, überschritten: 5 Minuten Sperre (HTTP 429); max. 500 Account-Tokens je Account, 50 User-Tokens je Nutzer.

Einschränkungen: Wert nur in der Antwort des Anlegens. Die Doku benennt das Start-Recht an zwei Stellen unterschiedlich („Account API Tokens Write“ in der Referenz, „Account > Account API Tokens > Edit“ im How-to); das ist vermutlich dieselbe Berechtigung in unterschiedlicher Benennung, unsicher. Zonen- und Account-Tokens haben unterschiedliche Permission-Groups. Bestandsrelevant für Uli: Account-Tokens sind laut Doku nicht für alle Endpunkte nutzbar („compatible endpoints“-Matrix), das vorher prüfen.

### 4.2 GitHub

- [G1] https://docs.github.com/en/rest/apps/apps — `POST /app/installations/{installation_id}/access_tokens`, Auth per JWT; optional `repositories`, `repository_ids` (bis 500), `permissions`; Token läuft nach 1 Stunde ab; Antwort `token`, `expires_at`, `permissions`.
- [G2] https://docs.github.com/en/rest/apps/installations — `DELETE /installation/token` widerruft das Token, mit dem man sich gerade authentisiert; `GET /app/installations` (JWT).
- [G3] https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens — Erstellung von classic und fine-grained PATs nur über Settings » Developer settings; Fine-grained: Ablauf wählbar, Organisationen können unbegrenzte Laufzeit verbieten; ungenutzte PATs werden nach einem Jahr entfernt; Org mit Freigabepflicht lässt neue Token `pending`. Dass es keinen API-Weg gibt, steht nirgends ausdrücklich; die Doku zeigt nur UI. Als „kein dokumentierter API-Weg“ zu lesen.
- [G4] https://docs.github.com/en/rest/credentials/revoke — `POST /credentials/revoke` für `ghp_`, `github_pat_`, `gho_`, `ghu_`, `ghr_`; ohne Authorization-Header (mit Header: 403); 60 Anfragen je Stunde, bis 1.000 Credentials je Anfrage; Besitzer werden benachrichtigt; nicht reaktivierbar.
- [G5] https://docs.github.com/en/rest/apps/oauth-applications — mit Basic-Auth (client_id:client_secret): `PATCH /applications/{client_id}/token` (Reset, altes Token sofort ungültig), `DELETE …/token`, `DELETE …/grant`.
- [G6] https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps — Private Keys einer App werden in den App-Einstellungen erzeugt und gelöscht; man muss einen neuen erzeugen, bevor der letzte gelöscht werden darf (UI-Beschreibung; eine REST-Variante wird nicht erwähnt, unsicher ob es keine gibt).
- [G7] https://docs.github.com/en/organizations/managing-programmatic-access-to-your-organization/reviewing-and-revoking-personal-access-tokens-in-your-organization — Org-Owner prüfen und widerrufen Fine-grained PATs per UI oder REST; die REST-Endpunkte „can only be called by GitHub Apps“. Classic PATs nur in der UI.
- [G8] https://docs.github.com/en/organizations/managing-programmatic-access-to-your-organization/github-credential-types — Übersicht je Credential-Typ (Laufzeit, Widerruf).

Einschränkungen: Der natürliche Weg für „niemand sieht einen Wert“ ist eine eigene GitHub App je Zweck: Secretariat hält den PEM (Kronjuwel) und erzeugt bei Bedarf 1-Stunden-Tokens mit Repo- und Rechte-Teilmenge. Ablauf ist nicht konfigurierbar (fest 1 h). Für Uli bleibt classic/fine-grained PAT beim Import-Weg. Ratenlimits der Token-Erzeugung: nicht geprüft.

### 4.3 OpenAI

Hinweis: `platform.openai.com/docs/api-reference/...` antwortete dem Abruf mit 403; die Inhalte kamen über das Abruf-Werkzeug der parallel-search-Schnittstelle von denselben OpenAI-Seiten und der neuen Referenz unter developers.openai.com.
- [O1] https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/admin_api_keys/methods/create — `POST /organization/admin_api_keys`; Body `name`, `expires_in_seconds` (1 bis 31.536.000); „value … Only shown on create“; Auth mit Admin-Key (`OPENAI_ADMIN_KEY`). Außerdem `GET /organization/admin_api_keys`, Retrieve, Delete.
- [O2] https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/projects/subresources/service_accounts/methods/create — `POST /organization/projects/{project_id}/service_accounts` (liefert standardmäßig einen unredacted `api_key`; `create_service_account_only`; `expires_in_seconds` für den ersten Key, Richtlinie kann Ablauf erzwingen).
- [O3] https://developers.openai.com/api/reference/python/resources/admin/subresources/organization/subresources/projects/subresources/service_accounts/subresources/api_keys/methods/create — `POST /organization/projects/{project_id}/service_accounts/{service_account_id}/api_keys`; Parameter `name`, `scopes`, `expires_in_seconds`; Antwort mit `value` (unredacted).
- [O4] https://platform.openai.com/docs/api-reference/project-service-accounts — Methoden: Create/Retrieve/Update/Delete/List für Service-Accounts, Create für deren API-Keys.
- [O5] https://platform.openai.com/docs/api-reference/project-api-keys — Projekt-Keys: List, Retrieve, Update, Delete (`DELETE /organization/projects/{project_id}/api_keys/{api_key_id}`); kein Create.
- [O6] https://help.openai.com/en/articles/9687866-admin-and-audit-logs-api-for-the-api-platform — „Only API Platform organization owners can create organization Admin keys“ (im UI mit wählbaren Berechtigungen); „List, retrieve, and delete API Keys in a Project“; verlorene Admin-Keys sind nicht wiederherstellbar.
- [O7] https://help.openai.com/en/articles/9186755-managing-projects-in-the-api-platform — Service-Account-Key wird einmal angezeigt; nur Org- und Projekt-Owner legen Service Accounts an; Standardrechte des Service-Account-Keys: alles im Projekt; Projekt-Key-Rechte All / Restricted / Read Only im UI.

Einschränkungen: Ein normaler Projekt-Key (User-Key) lässt sich nur im UI erstellen, ein Service-Account-Key per API: das ist der Weg für den Adapter. Welche Werte `scopes` annimmt, steht auf den abgerufenen Seiten nicht (unsicher). Ob ein Service-Account-Key über „Delete project API key“ gelöscht wird oder über einen eigenen Endpunkt, ist nicht belegt (unsicher, bei einem Durchstich testen). Ob der Admin-Key beim Anlegen eines weiteren Admin-Keys Rechte erbt oder alle bekommt, ist unsicher. Ratenlimit der Admin-API: nicht gefunden.

### 4.4 Anthropic

- [A1] https://platform.claude.com/docs/en/manage-claude/admin-api — FAQ: „Can I create new API keys through the Admin API? No. You create API keys in the Claude Console. The Admin API can only read, rename, and change the status of existing keys.“ Auth: Admin-Key (`sk-ant-admin…`, nur Rolle admin), OAuth `org:admin`, oder nicht workspace-gebundener Personal-/Service-Account-Key. Service-Account-, Federation-Issuer- und Federation-Rule-Endpunkte nehmen nur OAuth `org:admin`.
- [A2] https://platform.claude.com/docs/en/api/beta/organization/api_keys/update — `POST /v1/organizations/api_keys/{api_key_id}`; änderbar `name` und `status` (`active`, `inactive`, `archived`); Felder `expires_at`, `principal`, `scope`, `partial_key_hint`.
- [A3] https://platform.claude.com/docs/en/api/beta/organization/api_keys/list — `GET /v1/organizations/api_keys` mit Filtern `status`, `workspace_id`, `created_by_user_id`, `limit` bis 1000. Eine `create`-Seite existiert nicht (Abruf: 404).
- [A4] https://platform.claude.com/docs/en/manage-claude/authentication — Schlüssel entstehen in der Console; Ablauf wird beim Anlegen gewählt (Vorgaben 3 Std., 1 Tag, 7 Tage, 30 Tage, eigene Dauer, „Never“) und ist danach nicht änderbar; abgelaufene Schlüssel nur löschbar; Arten: Personal Key, Service-Account-Key, Workspace-Key (Legacy). Workload Identity Federation tauscht ein IdP-Token an `POST /v1/oauth/token` gegen ein kurzlebiges Zugriffstoken, „There is no sk-ant-api… string to mint, distribute, or rotate.“
- [A5] https://platform.claude.com/docs/en/manage-claude/wif-admin-api — per `org:admin`-OAuth: Service-Accounts, Issuer und Rules anlegen/listen/archivieren (`/v1/organizations/service_accounts`, `…/federation_issuers`, `…/federation_rules`); die erste `org:admin`-Rule muss ein Mensch in der Console anlegen („a deliberate human action, not something automation can bootstrap“).
- [A6] https://platform.claude.com/docs/en/manage-claude/admin-api-keys — Admin-Key nur in der Console, nur Rolle admin, Wert „shown only once“, Ablauf wählbar.

Einschränkungen: Anlegen per API: nein. Widerrufen (Deaktivieren/Archivieren) und Listen: ja. Damit funktioniert für Anthropic der Baustein „Sperren“ (z. B. nach `sweep`-Fund), nicht „Beschaffen“. Die Doku empfiehlt Workload Identity Federation statt langlebiger Schlüssel; für einen Mac-Secretsmanager ist das nur nützlich, wenn die Programme einen OIDC-Identitätsanbieter haben (unsicher für lokale Mac-Programme).

### 4.5 Google Cloud

- [Go1] https://cloud.google.com/api-keys/docs/reference/rest/v2/projects.locations.keys — Methoden `create`, `delete`, `get`, `getKeyString`, `list`, `patch`, `undelete` („Undeletes an API key which was deleted within 30 days“); Ressourcenfelder `displayName`, `restrictions` (`apiTargets[]`, genau eine Client-Restriktion aus Browser/Server-IP/Android/iOS), `serviceAccountEmail`; **kein Ablauf-Feld**. Seitenstand 2025-06 (Tool-Cache), unsicher, ob seitdem ein Ablauf-Feld dazukam.
- [Go2] https://cloud.google.com/api-keys/docs/reference/rest/v2/projects.locations.keys/create — `POST https://apikeys.googleapis.com/v2/{parent=projects/*/locations/*}/keys`, optionales `keyId`, Antwort ist eine Operation; Recht `apikeys.keys.create`.
- [Go3] …/keys/getKeyString — `GET …/{name}/keyString`, Recht `apikeys.keys.getKeyString`; der Wert steht also nicht in der Create-Antwort, sondern wird separat geholt (praktisch für „Wert nie anzeigen“).
- [Go4] …/keys/delete — `DELETE …/{name}`, 30 Tage wiederherstellbar, optional `etag`.
- [Go5] https://cloud.google.com/iam/docs/reference/rest/v1/projects.serviceAccounts.keys/create — `POST https://iam.googleapis.com/v1/{name=projects/*/serviceAccounts/*}/keys`; Body nur `privateKeyType`, `keyAlgorithm`.
- [Go6] https://cloud.google.com/iam/docs/keys-create-delete — bis zu 10 Schlüssel je Service Account; Schlüssel laufen standardmäßig nie ab, Ablauf nur per Org-Policy-Constraint für neue Schlüssel; Antwort enthält `privateKeyData`, `validAfterTime`, `validBeforeTime`; gelöscht heißt nicht wiederherstellbar, vorher deaktivieren (`keys.disable`/`keys.enable` existieren).
- [Go7] https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys — Constraints „Disable service account key creation“ und „Disable service account key upload“ sind für Organisationen ab 2024-05-03 standardmäßig erzwungen; Schlüssel gelten als Ausnahme.
- [Go8] https://ai.google.dev/gemini-api/docs/api-key — Gemini: seit 2026-05-28 sind neue AI-Studio-Keys „Auth keys“, gebunden an einen Service Account; Keys im Cloud-Konsolen-Weg müssen an einen Service Account gebunden werden; nicht eingeschränkte Standard-Keys werden von der Gemini-API abgelehnt; Rotationsablauf in der Doku: neu anlegen, ausrollen, alten deaktivieren und erst nach Prüfung löschen. Nötige Rechte zum Anlegen: u. a. `apikeys.keys.create`, `iam.serviceAccounts.create`, `iam.serviceAccountApiKeyBindings.create`.

Einschränkungen: Zwei verschiedene Mechanismen (API Keys API und IAM-Service-Account-Keys). Bootstrap ist ein Google-Credential (Nutzer oder Service Account), das Kurzzeit-Tokens erzeugt; wie genau Secretariat das auf dem Mac sicher hält, ist offen (Application Default Credentials, Impersonation: nicht geprüft). Ratenlimits/Kosten: nicht geprüft.

### 4.6 AWS

- [Aw1] https://docs.aws.amazon.com/IAM/latest/APIReference/API_CreateAccessKey.html — `CreateAccessKey(UserName?)`, Standardstatus `Active`, das Secret ist „accessible only during key and user creation“; Quoten stehen auf einer separaten Seite (nicht abgerufen). Dass es 2 Schlüssel je User sind, ist Allgemeinwissen, hier nicht belegt (Vermutung).
- [Aw2] https://docs.aws.amazon.com/IAM/latest/APIReference/API_DeleteAccessKey.html — `DeleteAccessKey(AccessKeyId, UserName?)`.
- Weitere Aktionen laut Inhaltsverzeichnis der IAM-Referenz: `ListAccessKeys`, `UpdateAccessKey` (Status), `GetAccessKeyLastUsed`.

Einschränkungen: Rechte hängen am IAM-User, nicht am Schlüssel; ein Ablaufdatum an Access Keys ist in der abgerufenen Referenz nicht vorgesehen (unsicher). AWS rät generell zu kurzlebigen STS-Credentials; nicht geprüft, hier nicht vertieft. Ob Uli AWS-Bestand hat, ist aus der Vorgabe nicht ersichtlich.

### 4.7 Supabase

- [S1] https://supabase.com/docs/reference/api/v1-create-project-api-key — `POST /v1/projects/{ref}/api-keys`; Body `type` (Pflicht), `name` (Pflicht), `description`, `secret_jwt_template`; Query `reveal`; OAuth-Scope `secrets:write`; feingranularer Token: `api_gateway_keys_write`; Antwort enthält `api_key`, `id`, `type`, `prefix`.
- [S2] https://supabase.com/docs/reference/api/v1-delete-project-api-key — `DELETE /v1/projects/{ref}/api-keys/{id}`; Query `was_compromised`, `reason`.
- [S3] https://supabase.com/docs/reference/api/v1-get-project-api-keys — `GET /v1/projects/{ref}/api-keys` (mit `reveal=true` liefert es die Werte; dann zusätzlich „API Key Secrets“-Leserecht); `GET …/{id}` für einen Key.
- [S4] https://supabase.com/docs/guides/platform/personal-access-tokens — Rechte-Matrix für scoped PATs: „API Keys“ Read / Read-write, „API Key Secrets“ Read.
- [S5] https://supabase.com/docs/reference/api/introduction — Auth: Personal Access Token (mit eigener Ablaufzeit, im Dashboard erzeugt) oder OAuth2; Limit 120 Anfragen je Minute je Nutzer, Projekt oder Organisation, Endpunkt (HTTP 429, `X-RateLimit-*`-Header).
- [S6] https://supabase.com/blog/scope-your-personal-access-tokens — Dashboard erzeugt PATs standardmäßig mit Scope (Präfix `sbp_fc`).
- [S7] https://supabase.com/docs/guides/api/api-keys — `sb_publishable_…`, `sb_secret_…`; `anon`/`service_role` werden bis Ende 2026 abgelöst; Rotationsablauf der Doku: neuen Secret Key anlegen, ersetzen, prüfen, dann den alten löschen („can't be undone“); ein Secret Key je Backend-Komponente empfohlen.

Einschränkungen: Keine Ablaufzeit je Schlüssel. Ob die Schlüsselverwaltung zusätzlich die Einsicht in die Werte braucht, steuern die Rechte „API Keys“ und „API Key Secrets“ getrennt: ein Adapter braucht zum Anlegen und Löschen keinen Lesezugriff auf bestehende Werte. Ein Scoped PAT lässt sich nach den abgerufenen Seiten nur im Dashboard anlegen; ein API-Weg ist nicht dokumentiert (unsicher). `list` mit `reveal=false` ist unkritisch.

### 4.8 Resend

- [R1] https://resend.com/docs/api-reference/api-keys/create-api-key — `POST https://api.resend.com/api-keys`; Body `name` (max. 50), `permission` (`full_access` | `sending_access`), optional Domain-Einschränkung nur bei `sending_access`; Antwort `{id, token}` mit `token` im Klartext.
- [R2] …/api-keys/list-api-keys — `GET /api-keys` (`limit` ≤ 100, `after`/`before`); Felder `id`, `name`, `created_at`, `last_used_at`, kein Wert.
- [R3] …/api-keys/delete-api-key — `DELETE /api-keys/{id}`.
- [R4] https://resend.com/docs/api-reference/rate-limit — 10 Anfragen je Sekunde je Team, über alle Keys.

Einschränkungen: Kein Ablauf. Verwalter-Credential ist selbst ein `full_access`-Key (der auch Mails verschicken und alles andere ändern kann); ein getrenntes „nur Keys verwalten“-Recht ist in der Doku nicht vorhanden (unsicher, nicht ausdrücklich verneint).

### 4.9 Stripe

- [St1] https://docs.stripe.com/keys und https://docs.stripe.com/keys/restricted-api-keys — Erstellen, Aufdecken, Ablaufen lassen und Rotieren nur über das Dashboard; Live-Wert wird einmal gezeigt, Erstellung verlangt Zwei-Faktor-Bestätigung; Rotation mit verzögertem Ablauf des alten Keys bis zu 7 Tage.
- [St2] https://docs.stripe.com/stripe-apps/api-authentication/managed-api-keys und https://docs.stripe.com/keys/managed-api-keys — „Managed API keys“: genehmigte Stripe Apps können per API Keys für ihre Nutzer anlegen und rotieren (Recht `api_key_write`, Events `v2.iam.api_key.rotated/expired`); **Preview**, Registrierung nötig. Für Ulis eigene Konten nicht nutzbar (Vermutung: setzt eine Stripe-App voraus).

### 4.10 Apple App Store Connect

- [Ap1] https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api — Team-Keys erzeugt nur ein Admin in App Store Connect; privater Schlüssel (.p8) „available for download a single time“.
- [Ap2] https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api — den API-Zugang beantragt der Account Holder; Widerruf im UI, „can’t be reinstated once revoked“.
- [Ap3] https://developer.apple.com/documentation/appstoreconnectapi/revoking-api-keys — Widerruf per Web-UI; widerrufene Schlüssel 30 Tage sichtbar.
- Zur Sicherheit: In der Doku-Navigation der API (Übersichtsseite abgerufen) kommt kein Ressourcentyp für Schlüssel vor; das ist ein Negativbeleg aus der Navigation, nicht aus einer ausdrücklichen Aussage („unsicher, aber stark wahrscheinlich nein“).

### 4.11 Lemon Squeezy

- [L1] https://docs.lemonsqueezy.com/guides/developer-guide/getting-started — Schlüssel entstehen in Settings » API; Wert wird einmal gezeigt; Namen später nicht änderbar.
- [L2] https://docs.lemonsqueezy.com/api/getting-started/requests — „Generated API keys are valid for a year“; Test- und Live-Modus haben getrennte Keys.
- Es gibt in der API-Referenz keinen Ressourcentyp für API-Keys (Inhaltsverzeichnis); Negativbeleg, wie bei Apple.

### 4.12 Hetzner Cloud

- [H1] https://docs.hetzner.com/cloud/api/getting-started/generating-api-token und https://docs.hetzner.cloud/reference/cloud — Token entstehen in der Console (Projekt » Security » API tokens), Rechte „Read“ oder „Read & Write“, an ein Projekt gebunden, Wert nur einmal sichtbar.
- [H2] https://docs.hetzner.com/cloud/api/faq/ — Token hat 64 Byte, die letzten 32 Byte geheim, nur gehasht gespeichert.
- Kein Endpunkt zum Verwalten von Tokens in der Referenz erkennbar (Negativbeleg aus der API-Beschreibung, unsicher).

### 4.13 Vercel

- [V1] https://vercel.com/docs/rest-api/authentication/create-an-auth-token — `POST /v3/user/tokens`, Body `name` (Pflicht), `expiresAt`, `projectId`; Query `teamId`/`slug`; `bearerToken` „only provided once“.
- [V2] https://vercel.com/docs/rest-api — Liste `GET /v6/user/tokens`, `GET /v5/user/tokens/{tokenId}`, `DELETE /v3/user/tokens/{tokenId}`.
- [V3] https://vercel.com/kb/guide/how-do-i-use-a-vercel-api-access-token — Anlegen über API oder CLI braucht ein Full-Account-Token; Team- und Projekt-Tokens können keine neuen Tokens anlegen.

Einschränkungen: Keine Rechte-Matrix, nur Scope (Account / Team / Projekt). Hinweis im Beleg: Die Dokumentation ist an einer Stelle als „oauth2-token“-Typ beschrieben; ob solche Tokens in der Praxis dieselbe Laufzeit wie im Dashboard erzeugte haben, ist unsicher.

### 4.14 Mailgun

- [M1] https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/keys/post-v1-keys — `POST /v1/keys`; Form: `role` (Pflicht: admin, basic, sending, developer), `kind` (domain, user, web), `domain_name`, `description`, `expiration` (Sekunden), `email`, `user_name`; Antwort `key.secret` „returned only once“, `key.expires_at`.
- [M2] https://documentation.mailgun.com/docs/mailgun/api-reference/send/mailgun/keys — Liste `GET /v1/keys`, `DELETE /v1/keys/{key_id}`, `POST /v1/keys/public`.
- [M3] https://help.mailgun.com/hc/en-us/articles/26016288026907-API-Key-Roles — RBAC-Rollen ab Foundation-Tarif; Free/Basic nur Admin; nur Admin darf Keys anlegen, löschen, rotieren und ablaufen lassen; Rolle nach dem Anlegen nicht änderbar.

### 4.15 Postmark

- [P1] https://postmarkapp.com/developer/user-guide/managing-your-account/managing-servers — Server anlegen mit Account-API-Token (Header `X-Postmark-Account-Token`, nur Account-Owner), Antwort enthält `ApiTokens[]`; „it’s possible to create new API tokens later“ (wie, steht nicht auf der Seite).
- [P2] https://postmarkapp.com/support/article/1008-what-are-the-account-and-server-api-tokens — drei Token-Arten (Account, Server, SMTP-Token); SMTP-Secret nach dem Anlegen nicht mehr sichtbar.
- Einzelnes Token anlegen, listen oder widerrufen per API: aus diesen Seiten nicht belegbar, unsicher. Ein Adapter ist ohne weitere Prüfung nicht planbar.

## 5. Offene Punkte

1. **OpenAI**: Werte des Feldes `scopes` und ob Service-Account-Keys über „Delete project API key“ gelöscht werden; Ratenlimit der Admin-API; ob ein Admin-Key weitere Admin-Keys mit eingeschränkten Rechten erzeugen kann (Body hat kein Rechtefeld).
2. **Cloudflare**: Bezeichnung des Start-Rechts („Write“ vs. „Edit“); Verhalten beim `PUT …/value` (Roll): ob das alte Token sofort tot ist; Kompatibilität der Account-Tokens mit allen von Uli genutzten Endpunkten (Pages/Workers/DNS).
3. **Google**: ob `apikeys` inzwischen ein Ablaufdatum kennt (Seitenstand 2025-06); welches Bootstrap-Credential auf dem Mac sicher und trotzdem bequem ist; Verhalten der Org-Policy beim Anlegen von Service-Account-Keys in Ulis Projekten (privates Konto ohne Organisation: Policy vermutlich nicht erzwungen, unsicher).
4. **GitHub**: ob eine REST-API für App-Private-Keys oder PATs existiert (Doku zeigt nur UI); Ratenlimits der Token-Erzeugung.
5. **Supabase**: ob Scoped PATs per API anlegbar sind; Ablaufverhalten des PAT selbst (Rotation des Kronjuwels).
6. **AWS**: Schlüsselquote je User und ob Ablauf möglich ist (nicht aus der Referenz abgeleitet); ob AWS im Bestand überhaupt eine Rolle spielt.
7. **Postmark, Resend**: Postmark-Tokenverwaltung; Resend: ob ein Key mit eingeschränktem Recht Keys verwalten kann.
8. **Stripe, Apple, Lemon Squeezy, Hetzner**: Negativbelege stützen sich auf das Fehlen in Doku und Navigation; ein expliziter Satz „nicht per API möglich“ fehlt (außer bei Anthropic).
9. **Übergreifend**: Bootstrap-Rotation (Admin-Key des Anbieters selbst rotieren) ist nur bei Cloudflare, OpenAI (Admin-Key per API) und Mailgun (Admin-Key per API) automatisierbar; bei Anthropic, Supabase-PAT, Resend ist sie ein manueller Schritt, bei dem der Mensch einen Wert sieht, es sei denn, der Import läuft direkt von der Anbieterseite in Secretariat.

## 6. Empfehlung

### 6.1 Die drei Anbieter für den ersten Adapter-Durchstich

1. **Cloudflare.** Größter Bestand, vollständigster API-Satz (anlegen, Policies, `expires_on`, IP-Bedingung, listen, `verify`, löschen, rollen), und der Verwalter lässt sich eng halten: ein Token, das nur „Account API Tokens Write“ trägt, mit IP-Filter und TTL (laut Cloudflare-Doku so empfohlen). Verwaltung und Nutzung sind sauber getrennt.
2. **OpenAI (Service-Account-Keys).** Großer Bestand. `POST …/service_accounts/{id}/api_keys` mit `name`, `scopes`, `expires_in_seconds`; Wert wird nur in der Antwort geliefert, wandert ohne Anzeige in Secretariat. Der Admin-Key lässt sich selbst per API mit Ablauf erzeugen. Einschränkung: bestehende Projekt-Keys im UI bleiben im Importweg; der Adapter schafft langfristig Service-Account-Schlüssel an deren Stelle.
3. **Supabase.** Beste Verwalter-Eingrenzung nach Cloudflare (Scoped PAT nur für „API Keys“, projektbegrenzt, mit Ablauf), einfacher Endpunktsatz, und `DELETE` kennt `was_compromised` und `reason`, passend zum Baustein „Sperren“ nach `sweep`. Die Supabase-Doku beschreibt selbst die Reihenfolge „neu, ersetzen, prüfen, löschen“.

Nächste Kandidaten: **Resend** (kleinster, schnellster Adapter und guter Testfall, aber Verwalter ist `full_access` und es gibt keinen Ablauf), **Mailgun** und **Vercel** (technisch gut, laut Vorgabe geringerer Bestand). **Anthropic** und **Google** haben großen Bestand, sind aber die schwierigeren Fälle: Anthropic nur Sperren (und Workload Identity Federation als Weg ohne Schlüssel), Google zweigleisig (API-Key-API plus IAM-Schlüssel) und mit Org-Policy-Hürden. **Dazu unabhängig vom Bootstrap:** `POST /credentials/revoke` von GitHub braucht kein Credential und eignet sich schon in Version 2 für „Sperren“ von `ghp_`/`github_pat_`-Funden aus `sweep` (60 Anfragen je Stunde, bis 1.000 Token je Anfrage).

### 6.2 Rotationsmuster je Anbieter (erst neu, verteilen, prüfen, dann alt widerrufen)

| Anbieter | Geht sauber? | Ablauf |
|---|---|---|
| Cloudflare | ja | neuen Token anlegen, `push`, Prüfaufruf (`GET …/tokens/verify` mit dem neuen Token), dann `DELETE` des alten. `PUT …/value` (Roll) nicht für Null-Ausfall nutzen, weil das alte Token laut Doku „invalidiert“ wird, der Zeitpunkt aber ungeklärt ist. |
| OpenAI | ja (mit Vorbehalt) | zweiten Service-Account-Key anlegen, verteilen, prüfen, alten Projekt-Key löschen. Mehrere Keys je Service Account sind nach der Referenz möglich (kein Limit genannt, unsicher), Löschpfad vorher testen. |
| Supabase | ja | in der Doku beschrieben: neuen Secret Key anlegen, überall ersetzen, prüfen, alten löschen (nicht rückgängig zu machen, deshalb erst nach der Prüfung). Je Komponente ein eigener Key. |
| Resend | ja | mehrere Keys parallel möglich, neuen anlegen, prüfen, alten per `DELETE` entfernen. Kein Ablauf als Sicherheitsnetz. |
| Mailgun, Vercel | ja | wie Resend; zusätzlich Ablauf von Anfang an setzen (`expiration`, `expiresAt`), damit vergessene alte Schlüssel von selbst enden. |
| Google API Key | ja, mit Rückfall | neu anlegen, ausrollen, alten löschen; 30 Tage `undelete` als Notbremse. Doku (Gemini) empfiehlt: alten erst deaktivieren oder löschen, wenn der neue läuft. |
| Google SA-Key | ja | bis zu 10 Schlüssel je Service Account; neuen anlegen, prüfen, alten `disable`n, später löschen (nicht wiederherstellbar). |
| AWS | ja (Quote beachten) | zweiten Key anlegen, prüfen, alten `Inactive` setzen, später löschen; Zahl der erlaubten Keys vorher prüfen. |
| GitHub App | Rotation entfällt | Installation Tokens laufen nach 1 Stunde ab; rotieren muss man nur den PEM (UI, neuer vor altem). |
| Anthropic | nein | nur Sperren per `status`; Rotation = neuer Schlüssel in der Console, dann Import, dann alten per API deaktivieren. |
| Stripe | nur im Dashboard | Rotation mit verzögertem Ablauf (bis 7 Tage) ist die sauberste Variante, aber nicht per API. |
| Apple, Lemon Squeezy, Hetzner | nein | Import-Weg wie heute; Secretariat kann nur Alter und Plan zur Erneuerung erinnern. |

### 6.3 Konsequenz für die Architektur (kurz)

- Adapter-Vertrag: `create(name, scopes, ttl) → Wert nur an Secretariat`, `list() → Metadaten ohne Wert`, `revoke(id)`, optional `verify()`. `ttl` und `scopes` sind je Anbieter nur teilweise abbildbar (siehe Tabelle); der Adapter meldet seine Fähigkeiten, der Richtlinienbaustein arbeitet damit.
- Das Bootstrap-Credential bekommt pro Anbieter die kleinste Rolle (Cloudflare: Account API Tokens Write; Supabase: API Keys Read-write ohne Secrets-Read; GitHub App: PEM nur für Installation Tokens). Resend ist der Ausreißer.
- Der Baustein „Sperren“ ist breiter anwendbar als „Beschaffen“: Anthropic (deaktivieren), GitHub (`/credentials/revoke`, ohne Credential), Supabase (`was_compromised`) funktionieren auch dort, wo das Anlegen im UI bleibt.

## Anzahl Belege

Primärquellen-Einträge im Abschnitt 4: Cloudflare 7, GitHub 8, OpenAI 7, Anthropic 6, Google 8, AWS 2, Supabase 7, Resend 4, Stripe 2, Apple 3, Lemon Squeezy 2, Hetzner 2, Vercel 3, Mailgun 3, Postmark 2 (zusammen 66).
