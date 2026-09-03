# Genereaza Instructiuni-CursorProGDC.pdf, RO/EN/ES, cu reportlab.
# Foloseste Arial (nu Helvetica standard-14) pentru diacriticele romanesti.
#
# AUDIT 2026-08-26: PDF-ul anterior (fara acest script, generat manual)
# era invechit si gresit pe 2 puncte reale, corectate aici:
# 1. Spunea ca aplicatia NU e semnata Apple si cerea click-dreapta ->
#    Deschide (bypass Gatekeeper) - FALS, aplicatia e semnata + notarizata
#    + stapled de mult (vezi CLAUDE.md, sectiunea "[ÎNVECHIT]" despre
#    eliminarea launcher-ului de bypass) - instalarea e directa, fara
#    avertismente.
# 2. Folosea "cumperi"/"cumpara" pentru cei 9 EUR - inlocuit cu formularea
#    de donatie (vezi CLAUDE.md Partea 1, Regula 3 - fara "pret"/
#    "cumpara"/"vanzare").
# Era si monolingv (doar RO) - acum RO/EN/ES, ca tot ecosistemul GDC.
#
# Ruleaza cu: python3 installer/generate_pdf.py
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, ListFlowable, ListItem, PageBreak, Image as RLImage, Spacer

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Instructiuni-CursorProGDC.pdf")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#B96A1E")
MUTED = colors.HexColor("#6a6a6a")
NOTE_BG = colors.HexColor("#FBF1E6")

title_style = ParagraphStyle("Title", parent=styles["Title"], fontName="Arial-Bold", fontSize=19, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontName="Arial", fontSize=11, textColor=MUTED, spaceAfter=20)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold", fontSize=13, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial", fontSize=10.5, leading=15, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
step_style = ParagraphStyle("Step", parent=body_style, leftIndent=4, spaceAfter=5)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG, leftIndent=10, fontSize=10)
footer_style = ParagraphStyle("Footer", parent=styles["Normal"], fontName="Arial", fontSize=8.5, textColor=colors.HexColor("#8a8a8a"), spaceBefore=20)
caption_style = ParagraphStyle("Caption", parent=styles["Normal"], fontName="Arial", fontSize=8.5, textColor=MUTED, alignment=1, spaceAfter=10)

# Capturi reale din aplicație (Preferințe), doar în română — etichetele din
# imagine sunt în RO, deci n-are sens să apară și în secțiunile EN/ES.
# PNG-urile din installer/screenshots/ sunt deja decupate manual la zona
# utilă a ferestrei (fără spațiul gol de sub conținut) și comise în repo,
# ca scriptul să rămână rulabil din nou fără să retrimită cineva capturi.
SCREENSHOTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenshots")
SCREENSHOT_ASPECT = 1217 / 490  # width / height, fix pt cele 3 capturi de mai jos


def screenshot(filename, caption):
    w = 15.5 * cm
    h = w / SCREENSHOT_ASPECT
    path = os.path.join(SCREENSHOTS_DIR, filename)
    return [Spacer(1, 4), RLImage(path, width=w, height=h), Paragraph(caption, caption_style)]


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(it, step_style), leftIndent=16) for it in items],
        bulletType="1", start="1", leftIndent=16, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    return Paragraph(text, note_style)


def page(d, images=None):
    images = images or {}
    flow = [Paragraph("CursorPro GDC", title_style), Paragraph(d["subtitle"], subtitle_style)]
    for h, body in d["sections"]:
        flow.append(Paragraph(h, h2_style))
        if isinstance(body, list):
            flow.append(numbered(body))
        elif isinstance(body, tuple):
            flow.append(note(body[0]))
        else:
            flow.append(Paragraph(body, body_style))
        for fname, caption in images.get(h, []):
            flow.extend(screenshot(fname, caption))
    flow.append(Paragraph("CursorPro GDC — github.com/gordasgdc/cursorpro-gdc", footer_style))
    return flow


RO = dict(
    subtitle="Instrucțiuni de instalare și utilizare — Română",
    sections=[
        ("1. Instalare", [
            "Descarcă fișierul <b>CursorProGDC.pkg</b> de pe pagina de descărcare sau din secțiunea Releases de pe GitHub.",
            "Dublu-click pe <b>CursorProGDC.pkg</b> — pachet semnat și notarizat oficial de Apple, se instalează direct, fără avertismente Gatekeeper și fără să confirmi nimic manual.",
            "Urmează pașii instalatorului. Va trebui să accepți Termenii și Condițiile pentru a continua. Aplicația se instalează automat în folderul Applications.",
        ]),
        ("2. Prima pornire și permisiunile", [
            "La prima deschidere, CursorPro GDC are nevoie de două permisiuni: <b>Accessibility</b> (ca să urmărească mouse-ul și tastele apăsate global) și <b>Screen Recording</b> (doar pentru funcția Zoom, ca să poată mări zona din jurul cursorului).",
            "Cel mai simplu: din meniul aplicației (iconița din bara de sus) → Preferințe → <b>Permisiuni</b>. Acolo apeși direct butonul de lângă fiecare permisiune — se deschide automat panoul corect din System Settings, nu trebuie să-l cauți singur.",
            "Dacă preferi manual: deschide System Settings (Command+Spațiu, scrie „System Settings”, Enter) → <b>Privacy & Security</b> → <b>Accessibility</b> (respectiv <b>Screen Recording</b>) → găsește <b>„CursorPro GDC”</b> în listă → apasă switch-ul ca să se facă verde/activ.",
            "<b>Atenție la nume asemănătoare:</b> dacă în listă apar DOUĂ intrări care par „CursorPro” (ex. una fără „GDC” în nume, rămasă de la o altă aplicație instalată/dezinstalată cândva), asigură-te că activezi exact cea numită <b>„CursorPro GDC”</b> — activarea intrării greșite pare că „nu se ține minte”, dar de fapt nu ai activat-o niciodată pe a noastră.",
            "Important: după ce acorzi o permisiune, închide complet aplicația (click-dreapta pe iconița din bara de sus → Închide CursorPro GDC) și redeschide-o din Applications — macOS nu aplică o permisiune nou-acordată unei aplicații deja pornite.",
            "Odată acordate corect, permisiunile rămân active la fiecare repornire a Mac-ului — nu trebuie repetate. Dacă totuși par să dispară, verifică din nou punctul de mai sus despre nume duplicate.",
            "CursorPro GDC nu înregistrează, stochează sau trimite nimic din ce vezi pe ecran — tot ce ține de Zoom se procesează local și dispare imediat ce eliberezi tasta.",
        ]),
        ("3. Folosire rapidă", "Toate modurile se activează ținând apăsată o tastă (reconfigurabil din Preferințe): <b>Halo cursor</b> (comutator permanent din meniu), <b>Spotlight</b> (implicit Control), <b>Desen</b> (implicit Option, 4 unelte), <b>Zoom</b> (implicit Shift, nivel de mărire 1.1x–12x, ajustabil fin din Preferințe sau live cu tasta Command + rotiță/gest trackpad)."),
        ("4. Funcții avansate", [
            "<b>Efecte de Clic</b> (Preferințe → Efecte Clic): un inel colorat apare la fiecare clic stânga, dreapta sau dublu-clic, fiecare cu culoarea lui — util în tutoriale, ca privitorii să vadă exact ce ai apăsat.",
            "<b>Afișare Taste Rapide</b> (Preferințe → Taste Afișate): combinația apăsată (ex. Cmd+C) apare lângă cursor — DOAR dacă include Command, Control sau Option, niciodată o literă simplă tastată (nu e un keylogger).",
            "<b>Preseturi Focus</b> (Preferințe → General): Tutorial, Studio Întunecat, Prezentator Contrast, Minimalist — aplică dintr-o mișcare halo, spotlight și efecte de clic potrivite.",
            "<b>Lupă avansată</b> (Preferințe → Zoom): Blocare cadru (Option+L, cât ții Zoom apăsat) — lupa rămâne fixă pe loc; Inspector de culoare — arată HEX/RGB/Display P3 al pixelului din centru; comutator Fluid/Pixeli reali pentru inspecție exactă de pixeli.",
            "<b>Semnal la schimbarea ecranului</b> (Preferințe → General, oprit implicit): util cu mai multe monitoare, ca publicul să găsească instant cursorul pe noul ecran.",
        ]),
        ("5. Trial și activare", [
            "Aplicația funcționează complet, fără restricții, timp de <b>3 zile</b> de la prima pornire. După aceea, funcțiile principale se opresc automat până activezi o licență.",
            "Deschide Preferințe → Licență. Acolo vezi ID-ul unic al calculatorului tău.",
            "Apasă „Scrie-mi pe WhatsApp pentru licență” — mesajul include automat ID-ul tău.",
            "După ce primești codul de licență, lipește-l în câmpul dedicat și apasă Activează.",
        ]),
        ("", ("<b>Donație:</b> 9 € — susține continuarea dezvoltării aplicației, o singură dată, fără abonament. Nu e o vânzare — activarea se face manual, prin WhatsApp, pe baza donației.",)),
        ("6. Actualizări", "Din meniul CursorPro GDC (bara de sus) → „Caută actualizări…” — verifică dacă există o versiune mai nouă și te duce direct la pagina de descărcare dacă da."),
        ("7. Suport", "Pentru orice întrebare, scrie-mi pe WhatsApp (buton în Preferințe → Licență) sau deschide un Issue pe GitHub."),
    ],
)

EN = dict(
    subtitle="Installation and usage instructions — English",
    sections=[
        ("1. Installation", [
            "Download <b>CursorProGDC.pkg</b> from the download page or the GitHub Releases section.",
            "Double-click <b>CursorProGDC.pkg</b> — a package officially signed and notarized by Apple, installs directly, no Gatekeeper warnings and nothing to confirm manually.",
            "Follow the installer steps. You'll need to accept the Terms and Conditions to continue. The app installs automatically into the Applications folder.",
        ]),
        ("2. First launch and permissions", [
            "On first launch, CursorPro GDC needs two permissions: <b>Accessibility</b> (to track the mouse and pressed keys globally) and <b>Screen Recording</b> (only for the Zoom feature, to magnify the area around the cursor).",
            "Easiest way: from the app's menu bar icon → Preferences → <b>Permissions</b>. Each row has its own button that opens the exact right System Settings pane for you — no need to hunt for it yourself.",
            "Manual way: open System Settings (Command+Space, type \"System Settings\", Enter) → <b>Privacy & Security</b> → <b>Accessibility</b> (and <b>Screen Recording</b>) → find <b>\"CursorPro GDC\"</b> in the list → toggle the switch on.",
            "<b>Watch out for similar names:</b> if the list shows TWO entries that look like \"CursorPro\" (e.g. one without \"GDC\" in the name, left over from some other app installed/removed a while ago), make sure you enable the one specifically named <b>\"CursorPro GDC\"</b> — toggling the wrong one looks like the permission \"isn't sticking\", but you never actually granted it to ours.",
            "Important: after granting a permission, fully quit the app (right-click the menu bar icon → Quit CursorPro GDC) and reopen it from Applications — macOS doesn't apply a newly granted permission to an already-running app.",
            "Once granted correctly, the permissions stay active across every restart — you don't need to repeat this. If they still seem to disappear, double-check the duplicate-name point above.",
            "CursorPro GDC never records, stores, or sends anything you see on screen — everything related to Zoom is processed locally and disappears the instant you release the key.",
        ]),
        ("3. Quick usage", "Every mode activates by holding a key (reconfigurable in Preferences): <b>Cursor Halo</b> (permanent toggle from the menu), <b>Spotlight</b> (default Control), <b>Draw</b> (default Option, 4 tools), <b>Zoom</b> (default Shift, 1.1x–12x magnification, fine-tunable in Preferences or live with the Command key + scroll wheel/trackpad gesture)."),
        ("4. Advanced features", [
            "<b>Click Effects</b> (Preferences → Click Effects): a colored ring appears on every left, right, or double click, each with its own color — great for tutorials, so viewers see exactly what you clicked.",
            "<b>Keystroke Overlay</b> (Preferences → Keystroke Overlay): the pressed combo (e.g. Cmd+C) appears near the cursor — ONLY when it includes Command, Control, or Option, never a plain typed letter (not a keylogger).",
            "<b>Focus Presets</b> (Preferences → General): Tutorial, Dark Studio, Presenter High-Contrast, Minimalist — apply a whole combination of halo, spotlight, and click-effect settings in one click.",
            "<b>Advanced loupe</b> (Preferences → Zoom): Lock Frame (Option+L, while holding Zoom) freezes the loupe in place; Color Inspector shows HEX/RGB/Display P3 of the center pixel; Smooth/Crisp Pixels toggle for exact pixel inspection.",
            "<b>Screen-change ping</b> (Preferences → General, off by default): useful with multiple monitors, so viewers instantly spot the cursor on the new screen.",
        ]),
        ("5. Trial and activation", [
            "The app works fully, with no restrictions, for <b>3 days</b> from first launch. After that, the main features stop automatically until you activate a license.",
            "Open Preferences → License. There you'll see your computer's unique ID.",
            "Tap \"Message me on WhatsApp for a license\" — the message automatically includes your ID.",
            "Once you receive the license code, paste it into the field and tap Activate.",
        ]),
        ("", ("<b>A donation, not a list price:</b> €9 — supports ongoing development, one-time, no subscription. Not a sale — activation happens manually, over WhatsApp, based on the donation.",)),
        ("6. Updates", "From the CursorPro GDC menu (top bar) → \"Check for Updates…\" — checks whether a newer version exists and takes you straight to the download page if so."),
        ("7. Support", "For any question, message me on WhatsApp (button in Preferences → License) or open an Issue on GitHub."),
    ],
)

ES = dict(
    subtitle="Instrucciones de instalación y uso — Español",
    sections=[
        ("1. Instalación", [
            "Descarga <b>CursorProGDC.pkg</b> desde la página de descarga o la sección Releases de GitHub.",
            "Doble clic en <b>CursorProGDC.pkg</b> — paquete firmado y notarizado oficialmente por Apple, se instala directamente, sin avisos de Gatekeeper y sin confirmar nada manualmente.",
            "Sigue los pasos del instalador. Deberás aceptar los Términos y Condiciones para continuar. La app se instala automáticamente en la carpeta Aplicaciones.",
        ]),
        ("2. Primer inicio y permisos", [
            "En el primer inicio, CursorPro GDC necesita dos permisos en System Settings → Privacy & Security: <b>Accessibility</b> (para rastrear el ratón y las teclas pulsadas globalmente) y <b>Screen Recording</b> (solo para la función Zoom, para ampliar el área alrededor del cursor).",
            "Importante: después de conceder un permiso, cierra completamente la app (clic derecho en el icono de la barra superior → Salir de CursorPro GDC) y vuelve a abrirla desde Aplicaciones — macOS no aplica un permiso recién concedido a una app ya en ejecución.",
            "CursorPro GDC nunca graba, almacena ni envía nada de lo que ves en pantalla — todo lo relacionado con Zoom se procesa localmente y desaparece en cuanto sueltas la tecla.",
        ]),
        ("3. Uso rápido", "Cada modo se activa manteniendo pulsada una tecla (reconfigurable en Preferencias): <b>Halo del cursor</b> (interruptor permanente desde el menú), <b>Spotlight</b> (por defecto Control), <b>Dibujo</b> (por defecto Option, 4 herramientas), <b>Zoom</b> (por defecto Shift, ampliación 1.1x–12x, ajustable con precisión en Preferencias o en vivo con la tecla Command + rueda/gesto del trackpad)."),
        ("4. Funciones avanzadas", [
            "<b>Efectos de Clic</b> (Preferencias → Efectos de Clic): un anillo de color aparece en cada clic izquierdo, derecho o doble clic, cada uno con su propio color — ideal para tutoriales, así los espectadores ven exactamente qué pulsaste.",
            "<b>Teclas en Pantalla</b> (Preferencias → Teclas en Pantalla): la combinación pulsada (p. ej. Cmd+C) aparece junto al cursor — SOLO si incluye Command, Control u Option, nunca una letra simple escrita (no es un keylogger).",
            "<b>Preajustes rápidos</b> (Preferencias → General): Tutorial, Estudio Oscuro, Presentador Alto Contraste, Minimalista — aplican de una vez una combinación de halo, foco y efectos de clic.",
            "<b>Lupa avanzada</b> (Preferencias → Zoom): Bloqueo de marco (Option+L, mientras mantienes Zoom) congela la lupa en su sitio; Inspector de color muestra HEX/RGB/Display P3 del píxel central; alternar Fluido/Píxeles reales para inspección exacta de píxeles.",
            "<b>Aviso de cambio de pantalla</b> (Preferencias → General, desactivado por defecto): útil con varios monitores, para que el público encuentre al instante el cursor en la nueva pantalla.",
        ]),
        ("5. Prueba y activación", [
            "La app funciona completamente, sin restricciones, durante <b>3 días</b> desde el primer inicio. Después, las funciones principales se detienen automáticamente hasta que actives una licencia.",
            "Abre Preferencias → Licencia. Allí verás el ID único de tu ordenador.",
            "Pulsa «Escríbeme por WhatsApp para la licencia» — el mensaje incluye automáticamente tu ID.",
            "Cuando recibas el código de licencia, pégalo en el campo correspondiente y pulsa Activar.",
        ]),
        ("", ("<b>Una donación, no un precio de lista:</b> 9 € — apoya el desarrollo continuo, una sola vez, sin suscripción. No es una venta — la activación se hace manualmente, por WhatsApp, en base a la donación.",)),
        ("6. Actualizaciones", "Desde el menú CursorPro GDC (barra superior) → «Buscar actualizaciones…» — comprueba si existe una versión más nueva y te lleva directamente a la página de descarga si la hay."),
        ("7. Soporte", "Para cualquier pregunta, escríbeme por WhatsApp (botón en Preferencias → Licencia) o abre un Issue en GitHub."),
    ],
)

RO_IMAGES = {
    "4. Funcții avansate": [
        ("general.png", "Preferințe → General — preseturi rapide de focus"),
        ("clicks.png", "Preferințe → Efecte Clic"),
        ("zoom.png", "Preferințe → Zoom — lupă avansată (scară fină, blocare cadru, scalare, inspector culoare)"),
    ],
}

doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm)
story = []
for i, (lang, images) in enumerate([(RO, RO_IMAGES), (EN, {}), (ES, {})]):
    story.extend(page(lang, images))
    if i < 2:
        story.append(PageBreak())
doc.build(story)
print("wrote", OUT)
