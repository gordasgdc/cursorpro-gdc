# CursorPro GDC — reguli de arhitectură

> **[SYSTEM DIRECTIVE FOR CLAUDE: DO NOT DELETE OR OVERWRITE EXISTING RULES. ONLY APPEND NEW RULES.]**
> Jurnal viu, nu document care se rescrie. La orice actualizare, adaugă la finalul secțiunii potrivite — nu șterge/înlocui reguli vechi decât dacă sunt explicit invalidate de o schimbare reală (și atunci marchează-le **[ÎNVECHIT]** cu motivul, nu le șterge din istoric).

Citit automat de Claude Code la fiecare sesiune în acest repo. App nativ Swift/AppKit, menu-bar only (`LSUIElement`), înlocuitor pentru "Pro Mouse for Mac". Vezi și memoria `cursorpro-project` pentru lecțiile tehnice complete (Zoom/TCC/signing).

## REGULĂ PERMANENTĂ: Locația proiectului pe disc (2026-08-25)
Acest repo trăiește în **`~/Developer/CursorPro`**, NU în `~/Downloads`.
Motiv: `~/Downloads` e curățat automat de CleanMyMac/Hazel pe acest Mac —
a șters alte repo-uri de sursă în timpul unei sesiuni de lucru anterioare
(recuperate din Coș la timp). Vezi `~/Developer/GDCPluginManager/PROJECT_STRUCTURE.md`
pentru context complet despre relocarea structurii de proiecte GDC.

## REGULĂ PERMANENTĂ: Uninstaller obligatoriu în orice pachet (2026-08-25)
Fiecare build/release TREBUIE să includă, alături de pachetul semnat și
notarizat:
1. Instalatorul (`.pkg` semnat cu `Developer ID Installer` + notarizat +
   stapled — vezi `build_installer.sh`).
2. **Uninstaller-ul complet** (`Dezinstalare_CursorPro.command`) — oprește
   procesele, resetează permisiunile TCC (`tccutil reset`), șterge
   aplicația + toate fișierele din `~/Library/` (Application Support,
   Caches, Preferences, Saved Application State, Logs). Cablat automat în
   `build_installer.sh` — copiat în `dist/` și inclus în
   `CursorProGDC-Mac.zip`, la rădăcina arhivei. NU genera un script nou de
   fiecare dată — editează `Dezinstalare_CursorPro.command` din rădăcina
   repo-ului, sursa unică de adevăr.

**[ÎNVECHIT 2026-08-25]** Exista anterior un launcher `Instalare_CursorPro.command`
care rula `xattr -dr com.apple.quarantine` pe `.pkg` înainte să-l deschidă —
ELIMINAT complet (fișier șters din repo). Motiv: pachetul e deja semnat +
notarizat + **stapled** (`xcrun stapler staple`, vezi `codesigning/sign-and-notarize.sh`),
deci Gatekeeper îl acceptă NATIV la dublu-click, cu sau fără quarantine flag —
orice comandă `xattr`/bypass e inutilă și arată neprofesionist/suspect,
exact cum a semnalat corect Cristi. Arhiva `CursorProGDC-Mac.zip` conține
acum DOAR 3 fișiere la rădăcină: `CursorProGDC.pkg`, `Dezinstalare_CursorPro.command`,
PDF-ul de instrucțiuni. Curățarea unei instalări vechi (evitarea a două
copii ale `.app` pe disc) se face acum corect, în `installer/scripts/preinstall`
(`pkgbuild --scripts`) — pkill + `rm -rf` pe copia veche, NIMIC legat de
Gatekeeper/quarantine acolo.
3. **Sincronizare 100% site ↔ GitHub Release**: linkul de descărcare de pe
   `docs/index.html` trebuie să trimită mereu la
   `releases/latest/download/CursorProGDC-Mac.zip` (niciodată la un tag
   fix sau un fișier hostat separat) — verificat 2026-08-25: linkul era deja
   corect, dar verifică din nou la orice restructurare de release.

Această regulă se aplică și la `gdc-plugin-manager` (Mac+Windows) — vezi
`CLAUDE.md`/`CHANGELOG.md` de acolo pentru portarea echivalentă.

## Bug investigat 2026-08-25: iconița din Menu Bar dispare instant

**Raportat**: aplicația pornește, iconița din bara de sus dispare aproape
instant, dar procesul rămâne viu (vizibil în Activity Monitor, necesită
Force Quit).

**Investigație făcută** (nu doar presupunere):
- Verificat live pe acest Mac: proces pornit, iconița confirmată prezentă
  prin Accessibility API (`osascript` → `menu bar item 1 of menu bar 1`,
  descriere "CursorPro") imediat după lansare ȘI după 15+ secunde — **nu
  am putut reproduce bug-ul aici**.
- `log show` pe procesul CursorPro în timpul lansării — niciun
  error/fault/exception.
- Revizuit tot codul `NSStatusItem`: un singur apel la `buildStatusItem()`,
  un singur punct de atribuire a `statusItem`, niciun `removeStatusItem`
  nicăieri, niciun al doilea `setActivationPolicy` care ar putea perturba
  starea. Simbolul SF (`cursorarrow.motionlines`) confirmat valid.
- Verificat garda de instanță unică (`NSRunningApplication.runningApplications`)
  — logica e corectă: instanța nouă se termină pe ea însăși dacă găsește
  una existentă, nu afectează instanța supraviețuitoare.

**Concluzie**: cel mai probabil specific configurației de sistem a
testerului (ex. "Automatically hide and show the menu bar" din Control
Center, Stage Manager, sau un monitor extern cu setări particulare), nu un
bug de cod reprodus aici. **Hardening aplicat** (fără a pretinde un fix
confirmat): `statusItem.isVisible = true` explicit + logging de diagnostic
în `DebugLog.swift` (`~/Desktop/cursorpro_debug.log`) la crearea
status item-ului.

**Pentru diagnosticare reală data viitoare**: cere testerului
`~/Desktop/cursorpro_debug.log` IMEDIAT după ce bug-ul apare (înainte de
Force Quit), plus versiunea exactă de macOS, dacă are Stage Manager
activ, și dacă are "Automatically hide and show the menu bar" activat în
System Settings → Control Center. Nu re-încerca fix-uri oarbe fără acest
semnal concret.

## DIRECTIVĂ PERMANENTĂ SUPREMĂ: Checklist obligatoriu la FIECARE release (2026-08-25)
Valabilă pentru TOATE aplicațiile ecosistemului GDC (CursorPro, GDC Plugin
Manager + Furnizor, GDC Plugin Manager Windows, DataMover, GDC Production
Manager, și orice proiect nou). Înainte de a raporta un release ca fiind
gata, TREBUIE bifate intern toate cele 4 puncte de mai jos — dacă unul
lipsește, spune-o explicit, nu declara release-ul "gata".

1. **Versiune vizibilă în UI** — About/Meniu/Settings/Footer trebuie să
   arate versiunea curentă (`v1.2.21` etc.), fără excepție.
2. **Verificator de actualizări** — la pornire sau printr-un buton
   „Caută actualizări", aplicația verifică versiunea de pe server/GitHub
   și notifică userul când există un release mai nou.
3. **Pachetul standard de release** — orice arhivă livrată clientului
   conține FĂRĂ EXCEPȚIE:
   - executabilul/installer-ul semnat + notarizat,
   - `Dezinstalare_[NumeAplicație].command` (dezinstalare completă:
     procese, permisiuni TCC, toate fișierele din `~/Library/`),
   - un ghid/PDF de instrucțiuni.
4. **Sincronizare site ↔ GitHub Releases** — linkurile de download de pe
   site trebuie să pointeze mereu la `releases/latest/download/...`
   (HTTP 200 verificat, nu presupus) și să menționeze numărul ultimei
   versiuni.
