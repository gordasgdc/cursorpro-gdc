# Changelog — CursorPro GDC

Jurnal scurt, orientat spre utilizator, al schimbărilor livrate clienților
— o intrare per versiune, cu dată. Complementar jurnalului tehnic detaliat
din CLAUDE.md (acolo sunt și deciziile/motivele/pitfall-urile; aici doar
rezumatul a "ce s-a schimbat", ușor de scanat rapid).

## v1.2.1 (2026-09-04) — Afișare Taste: control de mărime și opacitate

Preferințe → Taste Afișate capătă două slidere noi: **Mărime** (50%-200%,
scalează font + fundal împreună, nu doar textul) și **Opacitate**
(20%-100%, se înmulțește cu efectul de fade existent, nu-l înlocuiește).
Durata de afișare rămâne neschimbată.

## Website (gordas.dev/cursorpro-gdc) — descărcare duală Mac/Windows + detecție OS (2026-09-04)

Secțiunea Hero are acum două butoane distincte — „Descarcă pentru Mac" și
„Descarcă pentru Windows" — cu evidențiere automată a celui potrivit,
după sistemul de operare al vizitatorului (`navigator.userAgent`).
Butonul Windows rămâne marcat explicit „în curând" și trimite la repo-ul
`cursorpro-gdc-win` (nu la un fișier de descărcare, care încă nu există —
Regula 9, niciun link public presupus, doar verificat). Notă adăugată la
secțiunea „Instalare" (ascunsă implicit, vizibilă doar vizitatorilor
Windows) că pașii de acolo sunt încă doar pentru macOS.

## v1.2.0 (2026-09-03) — Zoom: scară fină 1.1x-12x, ⌘+Scroll live, Pixeli reali

Refactorizare completă a scalei de zoom, pe baza feedback-ului că nivelul
minim era prea agresiv și gradația prea brută:
- **Interval extins și continuu**: 1.1x (aproape imperceptibil) până la
  12x (inspecție de pixeli), în loc de treptele fixe 2x-6x de dinainte.
- **Control de precizie**: slider fin (pas 0.1x) + câmp numeric pentru
  o valoare exactă, în Preferințe → Zoom.
- **Ajustare live cu ⌘ + rotiță/gest trackpad**, cât lupa e activă —
  sensibilitate separată pentru trackpad (fin) vs. mouse cu rotiță
  (trepte mai mari), ca ambele să se simtă la fel de reactive.
- **Scalare Fluidă vs. Pixeli reali** (Preferințe → Zoom): Fluidă rămâne
  comportamentul de până acum; Pixeli reali randează explicit fără
  interpolare (nearest-neighbor), pentru designeri/editori care vor să
  vadă culoarea reală a fiecărui pixel, nu una estompată.

Reparat în același timp: ghidul din meniul Ajutor pentru Zoom nu avea
traducerile EN/ES actualizate cu mențiunea despre blocarea lupei și
inspectorul de culoare (adăugate în v1.1.0) — completat acum în toate
cele 3 limbi.

## v1.1.1 (2026-09-03) — Curățare cod (zero-legacy)

Audit complet al codului sursă, fără schimbări vizibile de funcționalitate:
- Reparat singurul warning de compilare din tot proiectul (captură `self`
  concurentă în `ZoomWindowController`, aliniat la convenția `@MainActor`
  deja folosită în alte locuri din același fișier).
- Găsit și reparat un cod mort real: câmpul `showCountdown` din
  `pricing.json` era decodat corect, dar afișajul numărătorii inverse
  (`countdownText`) nu era niciodată arătat în Preferințe → Licență —
  acum apare sub oferta activă, când Furnizorul îl activează.
- Audit complet: zero TODO/FIXME rămase, zero variabile/stare nefolosită,
  zero API învechit, zero force-unwrap riscant, zero fișiere temporare.
- Verificat: toate cele 6 funcții noi din v1.1.0 au cost zero pe CPU/GPU
  când sunt oprite (implicit) și nu acumulează memorie în sesiuni lungi
  (efectele de clic se curăță automat, în fiecare cadru).

## v1.1.0 (2026-09-03) — Efecte de clic, taste afișate, preseturi, lupă îmbunătățită

Șase funcții noi, toate opționale (implicit oprite, cu excepția presetului
care se aplică o singură dată la cerere):
- **Efecte de Clic**: un inel colorat, distinct pentru clic stânga, clic
  dreapta și dublu-clic, apare exact unde ai dat clic (Preferințe →
  Efecte Clic).
- **Afișare Taste Rapide**: combinația apăsată (ex. ⌘C) apare lângă cursor
  — DOAR dacă include ⌘/⌃/⌥, niciodată o literă simplă tastată (Preferințe
  → Taste Afișate).
- **Preseturi rapide** (Preferințe → General): Tutorial, Studio Întunecat,
  Prezentator Contrast, Minimalist — aplică dintr-o mișcare halo, spotlight
  și efecte de clic potrivite.
- **Semnal la schimbarea ecranului**, pentru configurații cu mai multe
  monitoare (Preferințe → General, oprit implicit).
- **Blocare cadru lupă** (⌥L implicit, cât ții tasta de Zoom): lupa rămâne
  fixă pe loc, ca să poți elibera mâna de pe poziția cursorului.
- **Inspector de culoare în lupă**: HEX/RGB/Display P3 al pixelului din
  centrul lupei (Preferințe → Zoom).

Meniul Ajutor din aplicație și paginile de Preferințe au fost actualizate
cu explicații pentru toate cele de mai sus.

## v1.0.7 (2026-08-31) — Zoom arăta conținut din spatele propriilor ferestre

Cauza reală a problemei de mai jos (v1.0.6): lupa de Zoom excludea din
captură TOATE ferestrele aplicației, nu doar suprapunerile transparente —
deci dacă țineai Zoom chiar deasupra ferestrei de Preferințe, aceasta
devenea invizibilă pentru lupă, care arăta în schimb orice se afla în
spatele ei pe ecran. Acum se exclud strict doar suprapunerile invizibile
(Halo/Spotlight/Desen) — orice fereastră reală, inclusiv Preferințele,
rămâne vizibilă și corect mărită.

## v1.0.6 (2026-08-31) — Zoom arăta uneori conținut dintr-o zonă greșită

La mișcări rapide/mari ale mouse-ului (ex. în timpul unei prezentări),
lupa de Zoom putea afișa pentru o clipă conținut dintr-o zonă complet
diferită de poziția reală a cursorului, în loc să urmărească exact locul
unde se află mouse-ul. Reparat.

## v1.0.5 (2026-08-31) — Preț dinamic din Furnizor

Suma de donație din fereastra de Preferințe (Licență) + mesajul WhatsApp
se citește acum din `pricing.json` (Furnizor), nu mai e fixă în cod —
orice ofertă programată apare automat, fără recompilare.
