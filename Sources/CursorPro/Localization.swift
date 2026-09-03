import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case ro, en, es
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ro: return "Română"
        case .en: return "English"
        case .es: return "Español"
        }
    }
}

/// Tiny in-app translation table, independent of system locale, matching
/// the same RO-default / EN / ES pattern used across this developer's
/// other apps. Persisted via UserDefaults so the choice sticks between
/// launches.
enum L {
    static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: "cursorpro_lang"),
               let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return .ro
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "cursorpro_lang") }
    }

    static func t(_ key: String) -> String {
        table[key]?[current] ?? table[key]?[.ro] ?? key
    }

    private static let table: [String: [AppLanguage: String]] = [
        "menu.title": [.ro: "CursorPro GDC", .en: "CursorPro GDC", .es: "CursorPro GDC"],
        "menu.halo": [.ro: "Halo cursor", .en: "Mouse Halo", .es: "Halo del cursor"],
        "menu.preferences": [.ro: "Preferințe…", .en: "Preferences…", .es: "Preferencias…"],
        "menu.quit": [.ro: "Închide CursorPro GDC", .en: "Quit CursorPro GDC", .es: "Salir de CursorPro GDC"],

        "prefs.title": [.ro: "Preferințe CursorPro GDC", .en: "CursorPro GDC Preferences", .es: "Preferencias de CursorPro GDC"],
        "prefs.language": [.ro: "Limbă", .en: "Language", .es: "Idioma"],

        "sidebar.general": [.ro: "General", .en: "General", .es: "General"],
        "sidebar.halo": [.ro: "Halo cursor", .en: "Mouse Halo", .es: "Halo del cursor"],
        "sidebar.spotlight": [.ro: "Spotlight", .en: "Spotlight", .es: "Foco"],
        "sidebar.draw": [.ro: "Desen", .en: "Draw", .es: "Dibujo"],
        "sidebar.zoom": [.ro: "Zoom", .en: "Zoom", .es: "Zoom"],
        "sidebar.shortcuts": [.ro: "Taste rapide", .en: "Shortcuts", .es: "Atajos"],
        "sidebar.permissions": [.ro: "Permisiuni", .en: "Permissions", .es: "Permisos"],

        "perm.subtitle": [.ro: "CursorPro GDC are nevoie de aceste permisiuni ca să funcționeze corect pe tot ecranul.",
                           .en: "CursorPro GDC needs these permissions to work correctly across your whole screen.",
                           .es: "CursorPro GDC necesita estos permisos para funcionar correctamente en toda la pantalla."],
        "perm.accessibility.why": [.ro: "Face urmărirea globală a mouse-ului și a tastelor ținute apăsat (fn/⌥/⌃/⌘) fiabilă, indiferent ce aplicație e activă.",
                                    .en: "Makes global mouse and held-key tracking (fn/⌥/⌃/⌘) reliable, no matter which app is active.",
                                    .es: "Hace que el seguimiento global del ratón y las teclas mantenidas (fn/⌥/⌃/⌘) sea fiable, sin importar qué app esté activa."],
        "perm.screenRecording.why": [.ro: "Necesară doar pentru Zoom — ca să poată capta și mări zona din jurul cursorului.",
                                      .en: "Needed only for Zoom — to capture and magnify the area around your cursor.",
                                      .es: "Necesario solo para Zoom — para capturar y ampliar el área alrededor de tu cursor."],

        "prefs.enabled": [.ro: "Activat", .en: "Enabled", .es: "Activado"],
        "prefs.color": [.ro: "Culoare", .en: "Color", .es: "Color"],
        "prefs.size": [.ro: "Mărime", .en: "Size", .es: "Tamaño"],
        "prefs.lineThickness": [.ro: "Grosime linie", .en: "Line thickness", .es: "Grosor de línea"],
        "prefs.style": [.ro: "Stil", .en: "Style", .es: "Estilo"],
        "prefs.style.ring": [.ro: "Inel", .en: "Ring", .es: "Anillo"],
        "prefs.style.filled": [.ro: "Plin", .en: "Filled", .es: "Relleno"],
        "prefs.style.crosshair": [.ro: "Cruce", .en: "Crosshair", .es: "Retícula"],

        "prefs.radius": [.ro: "Rază", .en: "Radius", .es: "Radio"],
        "prefs.dimAmount": [.ro: "Intensitate întunecare", .en: "Dim amount", .es: "Intensidad de oscurecido"],

        "prefs.clearAll": [.ro: "Șterge tot desenul", .en: "Clear all drawings", .es: "Borrar todo el dibujo"],
        "prefs.tool": [.ro: "Unealtă", .en: "Tool", .es: "Herramienta"],
        "draw.tool.freehand": [.ro: "Liber (mână liberă)", .en: "Freehand", .es: "Mano alzada"],
        "draw.tool.arrow": [.ro: "Săgeată", .en: "Arrow", .es: "Flecha"],
        "draw.tool.ellipse": [.ro: "Încercuire", .en: "Circle", .es: "Círculo"],
        "draw.tool.rectangle": [.ro: "Cadru de selecție", .en: "Selection frame", .es: "Marco de selección"],
        "draw.tool.hint": [.ro: "Liber: mișcă mouse-ul cu tasta apăsată. Săgeată/Cerc/Cadru: apasă tasta, apoi trage clic de la un colț la altul.",
                            .en: "Freehand: move the mouse while holding the key. Arrow/Circle/Frame: hold the key, then click-drag from one point to another.",
                            .es: "Mano alzada: mueve el ratón con la tecla pulsada. Flecha/Círculo/Marco: mantén la tecla y arrastra de un punto a otro."],
        "menu.drawTool": [.ro: "Unealtă desen", .en: "Draw Tool", .es: "Herramienta de dibujo"],

        "shortcut.pressKey": [.ro: "Apasă o tastă…", .en: "Press a key…", .es: "Pulsa una tecla…"],
        "shortcut.none": [.ro: "Nesetat", .en: "Not set", .es: "Sin asignar"],
        "shortcut.drawTools": [.ro: "Taste rapide — unelte de desen", .en: "Shortcut keys — draw tools", .es: "Teclas rápidas — herramientas de dibujo"],
        "shortcut.drawTools.hint": [.ro: "Comută instant unealta activă, indiferent dacă ții apăsată tasta de desen — utile ca să pregătești unealta chiar înainte să desenezi, în timpul unei prezentări live.",
                                     .en: "Instantly switches the active tool, whether or not the draw key is held — handy for pre-selecting a tool right before you draw, mid live presentation.",
                                     .es: "Cambia al instante la herramienta activa, con o sin la tecla de dibujo pulsada — útil para preseleccionar la herramienta justo antes de dibujar, en plena presentación en vivo."],
        "shortcut.click.to.record": [.ro: "Click pe tastă ca s-o schimbi", .en: "Click the key to change it", .es: "Haz clic en la tecla para cambiarla"],

        "sidebar.help": [.ro: "Ajutor", .en: "Help", .es: "Ayuda"],
        "help.intro": [.ro: "CursorPro GDC adaugă instrumente de prezentare peste orice aplicație: un halo în jurul cursorului, un spotlight care întunecă restul ecranului, desen liber sau cu forme (săgeți, cercuri, cadre), și o lupă digitală. Toate se activează ținând apăsată o tastă — nimic nu rămâne pornit din greșeală.",
                         .en: "CursorPro GDC layers presentation tools on top of any app: a halo around the cursor, a spotlight that dims the rest of the screen, freehand or shape drawing (arrows, circles, frames), and a digital magnifier. Everything activates by holding a key — nothing stays on by accident.",
                         .es: "CursorPro GDC añade herramientas de presentación sobre cualquier app: un halo alrededor del cursor, un foco que oscurece el resto de la pantalla, dibujo libre o con formas (flechas, círculos, marcos) y una lupa digital. Todo se activa manteniendo pulsada una tecla — nada queda encendido por accidente."],

        "help.halo.title": [.ro: "Halo cursor", .en: "Mouse Halo", .es: "Halo del cursor"],
        "help.halo.body": [.ro: "Un cerc vizibil în jurul cursorului, ca publicul să-l urmărească ușor pe ecran proiectat. Îl activezi/dezactivezi permanent din meniu sau din Preferințe. Stil (inel/plin/cruce), culoare, mărime și grosime — toate reglabile din Preferințe → Halo cursor.",
                            .en: "A visible ring around the cursor so your audience can follow it easily on a projected screen. Toggle it permanently on/off from the menu or Preferences. Style (ring/filled/crosshair), color, size, and thickness are all adjustable in Preferences → Mouse Halo.",
                            .es: "Un círculo visible alrededor del cursor para que el público lo siga fácilmente en pantalla proyectada. Actívalo/desactívalo de forma permanente desde el menú o Preferencias. Estilo (anillo/relleno/retícula), color, tamaño y grosor son ajustables en Preferencias → Halo del cursor."],

        "help.spotlight.title": [.ro: "Spotlight", .en: "Spotlight", .es: "Foco"],
        "help.spotlight.body": [.ro: "Ține apăsată tasta de Spotlight (implicit Control) ca să întuneci tot ecranul, cu excepția unui cerc luminos în jurul cursorului — perfect pentru a atrage atenția pe o zonă anume. Rază și intensitate întunecare — din Preferințe → Spotlight.",
                                 .en: "Hold the Spotlight key (default Control) to dim the whole screen except a bright circle around the cursor — perfect for pulling attention to one spot. Radius and dim amount are in Preferences → Spotlight.",
                                 .es: "Mantén pulsada la tecla de Foco (por defecto Control) para oscurecer toda la pantalla excepto un círculo brillante alrededor del cursor — perfecto para atraer la atención a un punto. Radio e intensidad de oscurecido en Preferencias → Foco."],

        "help.draw.title": [.ro: "Desen (liber, săgeți, cercuri, cadre)", .en: "Draw (freehand, arrows, circles, frames)", .es: "Dibujo (libre, flechas, círculos, marcos)"],
        "help.draw.body": [.ro: "Ține apăsată tasta de Desen (implicit Option) ca să desenezi peste orice aplicație. 4 unelte: Liber (mișcă mouse-ul), Săgeată, Încercuire, Cadru de selecție (ultimele 3: apasă tasta, apoi trage clic de la un colț la altul). Schimbi unealta din meniu, din Preferințe → Desen, sau — cel mai rapid — cu tastele rapide dedicate (vezi mai jos și pagina Taste rapide). Culoare și grosime linie — din Preferințe → Desen. Ștergi tot desenul cu tasta de Ștergere (implicit Command) sau din Preferințe.",
                            .en: "Hold the Draw key (default Option) to draw over any app. 4 tools: Freehand (just move the mouse), Arrow, Circle, Selection Frame (the last 3: hold the key, then click-drag from one point to another). Switch tools from the menu, from Preferences → Draw, or — fastest — with the dedicated shortcut keys (see below and the Shortcuts page). Color and line thickness are in Preferences → Draw. Clear everything with the Clear key (default Command) or from Preferences.",
                            .es: "Mantén pulsada la tecla de Dibujo (por defecto Option) para dibujar sobre cualquier app. 4 herramientas: Libre (mueve el ratón), Flecha, Círculo, Marco de selección (las 3 últimas: mantén la tecla y arrastra de un punto a otro). Cambia de herramienta desde el menú, desde Preferencias → Dibujo o — lo más rápido — con las teclas rápidas dedicadas (ver abajo y la página de Teclas rápidas). Color y grosor de línea en Preferencias → Dibujo. Borra todo con la tecla de Borrado (por defecto Command) o desde Preferencias."],

        "help.zoom.title": [.ro: "Zoom", .en: "Zoom", .es: "Zoom"],
        "help.zoom.body": [.ro: "Mișcă mouse-ul normal până ajungi exact unde vrei să arăți ceva, apoi ține apăsată tasta de Zoom (implicit Shift) — abia atunci apare lupa digitală, rotundă, fixă pe acel punct. Nu ține tasta cât te miști spre țintă — orientează-te normal, cu mouse-ul liber, și abia la final ții tasta. Nivelul de mărire (1.1x-12x, cu pas fin de 0.1x) se alege din Preferințe → Zoom, sau live, ținând ⌘ și derulând rotița/gestul de pe trackpad cât lupa e activă. Din Preferințe → Zoom poți și bloca lupa pe loc (⌥L implicit, cât ții tasta de Zoom apăsată), comuta între scalare Fluidă și Pixeli reali (util la mărire mare), și afișa culoarea exactă (HEX/RGB/Display P3) a pixelului din centru. Necesită permisiunea Înregistrare ecran.",
                            .en: "Move the mouse normally until you're exactly where you want to point at something, then hold the Zoom key (default Shift) — only then does the round digital loupe appear, fixed on that spot. Don't hold the key while moving toward the target — navigate normally with the mouse free, and hold the key only once you've arrived. Magnification level (1.1x-12x, in fine 0.1x steps) is set in Preferences → Zoom, or live — hold ⌘ and scroll/swipe on the trackpad while the loupe is active. Preferences → Zoom also lets you lock the loupe in place (default ⌥L, while holding the Zoom key), switch between Smooth and Crisp Pixels scaling (useful at high magnification), and show the exact color (HEX/RGB/Display P3) of the pixel at the center. Requires Screen Recording permission.",
                            .es: "Mueve el ratón con normalidad hasta llegar exactamente donde quieres señalar algo, luego mantén pulsada la tecla de Zoom (por defecto Shift) — solo entonces aparece la lupa digital redonda, fija en ese punto. No mantengas la tecla mientras te desplazas hacia el objetivo — navega con normalidad, con el ratón libre, y mantén la tecla solo al llegar. El nivel de ampliación (1.1x-12x, en pasos finos de 0.1x) se ajusta en Preferencias → Zoom, o en vivo — mantén ⌘ y desplaza la rueda/gesto del trackpad mientras la lupa está activa. Preferencias → Zoom también permite bloquear la lupa en su sitio (⌥L por defecto, mientras mantienes la tecla de Zoom), alternar entre escalado Fluido y Píxeles reales (útil con mucha ampliación), y mostrar el color exacto (HEX/RGB/Display P3) del píxel central. Requiere el permiso de Grabación de pantalla."],

        "help.shortcuts.title": [.ro: "Taste rapide, toate reconfigurabile", .en: "Shortcut keys, all reconfigurable", .es: "Teclas rápidas, todas reconfigurables"],
        "help.shortcuts.body": [.ro: "Fiecare mod (Zoom, Desen, Spotlight, Ștergere) e legat de o tastă modificator ținută apăsată — le schimbi din Preferințe → Taste rapide. În plus, fiecare unealtă de desen are propria combinație de taste (implicit ⌥1–⌥4) care comută instant unealta, fără să ții nicio tastă apăsată — ideal când te miști rapid într-o prezentare live. Click pe combinația afișată, apoi apasă noua tastă dorită; Esc anulează.",
                                 .en: "Each mode (Zoom, Draw, Spotlight, Clear) is bound to a modifier key you hold — change these in Preferences → Shortcuts. On top of that, each draw tool has its own key combo (default ⌥1–⌥4) that instantly switches tools, no key needs to be held — ideal for moving fast in a live presentation. Click the shown combo, then press the new key you want; Esc cancels.",
                                 .es: "Cada modo (Zoom, Dibujo, Foco, Borrado) está ligado a una tecla modificadora que mantienes pulsada — cámbialas en Preferencias → Teclas rápidas. Además, cada herramienta de dibujo tiene su propia combinación (por defecto ⌥1–⌥4) que cambia de herramienta al instante, sin mantener ninguna tecla — ideal para moverte rápido en una presentación en vivo. Haz clic en la combinación mostrada y pulsa la nueva tecla; Esc cancela."],

        "help.permissions.title": [.ro: "Permisiuni", .en: "Permissions", .es: "Permisos"],
        "help.permissions.body": [.ro: "Accesibilitate: necesară pentru urmărirea fiabilă a mouse-ului/tastelor și pentru tastele rapide ale uneltelor de desen. Înregistrare ecran: necesară doar pentru Zoom. Le verifici oricând în pagina Permisiuni — punct verde = acordată, roșu = lipsă (click pentru a o acorda din Setări Sistem).",
                                   .en: "Accessibility: needed for reliable mouse/key tracking and for the draw-tool shortcut keys. Screen Recording: needed only for Zoom. Check either anytime on the Permissions page — green dot = granted, red = missing (click to grant it in System Settings).",
                                   .es: "Accesibilidad: necesaria para el seguimiento fiable del ratón/teclas y para las teclas rápidas de las herramientas de dibujo. Grabación de pantalla: solo necesaria para Zoom. Revísalas cuando quieras en la página de Permisos — punto verde = concedido, rojo = falta (clic para concederlo en Ajustes del Sistema)."],

        "help.tips.title": [.ro: "Sfaturi pentru prezentări live", .en: "Tips for live presentations", .es: "Consejos para presentaciones en vivo"],
        "help.tips.body": [.ro: "• Pregătește unealta de desen din timp cu tasta ei rapidă, înainte să ai nevoie de ea.\n• Alege taste modificator care nu se ciocnesc cu scurtăturile aplicației pe care o prezinți (de ex. DaVinci Resolve).\n• Folosește Ștergere (implicit Command) între exemple, ca ecranul să rămână curat.\n• Un Preset rapid (Preferințe → General) îți setează dintr-o mișcare halo, spotlight și efecte de clic potrivite pentru tutorial, studio întunecat sau prezentare cu contrast mare.\n• Cu mai multe monitoare, activează Semnalul la schimbarea ecranului (Preferințe → General) ca publicul să găsească instant cursorul pe noul ecran.\n• CursorPro GDC rulează doar din bara de meniu — nu apare în Dock și nu fură focus de la aplicația prezentată.",
                             .en: "• Pre-select the draw tool with its shortcut before you need it.\n• Pick modifier keys that don't clash with the shortcuts of the app you're presenting (e.g. DaVinci Resolve).\n• Use Clear (default Command) between examples to keep the screen tidy.\n• CursorPro GDC runs only from the menu bar — it never appears in the Dock and never steals focus from the app you're presenting.",
                             .es: "• Preselecciona la herramienta de dibujo con su tecla rápida antes de necesitarla.\n• Elige teclas modificadoras que no choquen con los atajos de la app que estás presentando (p. ej. DaVinci Resolve).\n• Usa Borrado (por defecto Command) entre ejemplos para mantener la pantalla limpia.\n• CursorPro GDC solo se ejecuta desde la barra de menú — nunca aparece en el Dock ni roba el foco de la app que estás presentando."],

        "prefs.zoomLevel": [.ro: "Nivel zoom", .en: "Zoom level", .es: "Nivel de zoom"],
        "prefs.zoomLevel.hint": [.ro: "Cât de mult mărește lupa (1.1x-12x, ajustare fină din 0.1 în 0.1). Ține ⌘ și derulează rotița/trackpad-ul cât lupa e activă, pentru ajustare live. Mișcă mouse-ul normal până ajungi exact unde vrei, apoi ține tasta de Zoom — abia atunci apare lupa, fixă pe punctul respectiv.",
                                  .en: "How strongly the loupe magnifies (1.1x-12x, in fine 0.1 steps). Hold ⌘ and scroll/swipe on the trackpad while the loupe is active to adjust it live. Move the mouse normally until you're exactly where you want, then hold the Zoom key — only then does the loupe appear, fixed on that spot.",
                                  .es: "Cuánto amplía la lupa (1.1x-12x, en pasos finos de 0.1). Mantén ⌘ y desplaza la rueda/trackpad mientras la lupa está activa, para ajustarla en vivo. Mueve el ratón con normalidad hasta llegar exactamente donde quieres, luego mantén la tecla de Zoom — solo entonces aparece la lupa, fija en ese punto."],

        "prefs.key.zoom": [.ro: "Zoom", .en: "Zoom", .es: "Zoom"],
        "prefs.key.draw": [.ro: "Desen", .en: "Draw", .es: "Dibujo"],
        "prefs.key.spotlight": [.ro: "Spotlight", .en: "Spotlight", .es: "Foco"],
        "prefs.key.clear": [.ro: "Șterge desenul", .en: "Clear drawings", .es: "Borrar dibujo"],

        "prefs.startAtLogin": [.ro: "Pornește la login", .en: "Start at login", .es: "Iniciar al arrancar sesión"],

        "menu.permissions": [.ro: "Permisiuni", .en: "Permissions", .es: "Permisos"],
        "perm.accessibility": [.ro: "Accesibilitate", .en: "Accessibility", .es: "Accesibilidad"],
        "perm.screenRecording": [.ro: "Înregistrare ecran", .en: "Screen Recording", .es: "Grabación de pantalla"],
        "perm.granted": [.ro: "acordată", .en: "granted", .es: "concedido"],
        "perm.missing": [.ro: "lipsă — click pentru a acorda", .en: "missing — click to grant", .es: "falta — clic para conceder"],
        "prefs.openSettings": [.ro: "Deschide Setări Sistem", .en: "Open System Settings", .es: "Abrir Ajustes del Sistema"],
        "prefs.refresh": [.ro: "Reverifică", .en: "Recheck", .es: "Volver a comprobar"],

        "key.function": [.ro: "fn", .en: "fn", .es: "fn"],
        "key.option": [.ro: "Option (⌥)", .en: "Option (⌥)", .es: "Option (⌥)"],
        "key.control": [.ro: "Control (⌃)", .en: "Control (⌃)", .es: "Control (⌃)"],
        "key.command": [.ro: "Command (⌘)", .en: "Command (⌘)", .es: "Command (⌘)"],
        "key.shift": [.ro: "Shift (⇧)", .en: "Shift (⇧)", .es: "Shift (⇧)"],

        // MARK: - License

        "sidebar.license": [.ro: "Licență", .en: "License", .es: "Licencia"],
        "license.status.trial": [.ro: "Perioadă de probă", .en: "Trial", .es: "Prueba"],
        "license.status.trial.daysLeft": [.ro: "Mai ai %d zile de probă gratuită.", .en: "%d days left in your free trial.", .es: "Te quedan %d días de prueba gratuita."],
        "license.status.trial.lastDay": [.ro: "Ultima zi de probă gratuită.", .en: "Last day of your free trial.", .es: "Último día de tu prueba gratuita."],
        "license.status.expired": [.ro: "Perioada de probă s-a încheiat", .en: "Trial expired", .es: "Prueba caducada"],
        "license.status.expired.body": [.ro: "Funcțiile CursorPro GDC (Halo, Spotlight, Desen, Zoom) sunt oprite până activezi o licență.",
                                         .en: "CursorPro GDC's features (Halo, Spotlight, Draw, Zoom) are off until you activate a license.",
                                         .es: "Las funciones de CursorPro GDC (Halo, Foco, Dibujo, Zoom) están desactivadas hasta que actives una licencia."],
        "license.status.licensed": [.ro: "Licențiat", .en: "Licensed", .es: "Con licencia"],
        "license.status.licensed.body": [.ro: "Mulțumesc! Toate funcțiile sunt active, fără limită de timp.",
                                          .en: "Thank you! All features are unlocked, no time limit.",
                                          .es: "¡Gracias! Todas las funciones están activas, sin límite de tiempo."],
        "license.field.placeholder": [.ro: "Lipește aici codul de licență", .en: "Paste your license code here", .es: "Pega aquí tu código de licencia"],
        "license.activate": [.ro: "Activează", .en: "Activate", .es: "Activar"],
        "license.deactivate": [.ro: "Dezactivează pe acest calculator", .en: "Deactivate on this Mac", .es: "Desactivar en este Mac"],
        "license.buy.title": [.ro: "Nu ai încă o licență?", .en: "Don't have a license yet?", .es: "¿Aún no tienes una licencia?"],
        "license.buy.button": [.ro: "Scrie-mi pe WhatsApp pentru licență", .en: "Message me on WhatsApp for a license", .es: "Escríbeme por WhatsApp para la licencia"],
        "license.error.malformed": [.ro: "Codul nu e valid — verifică să-l fi copiat complet.", .en: "That code isn't valid — check you copied all of it.", .es: "Ese código no es válido — comprueba que lo copiaste completo."],
        "license.error.badSignature": [.ro: "Codul nu e valid.", .en: "That code isn't valid.", .es: "Ese código no es válido."],
        "license.error.wrongProduct": [.ro: "Acest cod e pentru altă aplicație.", .en: "This code is for a different app.", .es: "Este código es para otra aplicación."],
        "license.error.wrongMachine": [.ro: "Acest cod e activat pentru alt calculator.", .en: "This code is activated for a different Mac.", .es: "Este código está activado para otro Mac."],
        "license.error.expired": [.ro: "Acest cod a expirat.", .en: "This code has expired.", .es: "Este código ha caducado."],
        "license.activated.success": [.ro: "Activat cu succes!", .en: "Activated successfully!", .es: "¡Activado correctamente!"],

        "license.machineID.title": [.ro: "ID-ul calculatorului tău", .en: "Your Mac's ID", .es: "El ID de tu Mac"],
        "license.machineID.body": [.ro: "Trimite-mi acest cod când faci donația pentru licență — o leagă de calculatorul acesta, ca să nu poată fi folosită de altcineva.",
                                    .en: "Send me this code when you donate for a license — it ties it to this Mac, so it can't be used by anyone else.",
                                    .es: "Envíame este código cuando hagas la donación por la licencia — la vincula a este Mac, para que nadie más pueda usarla."],
        "license.machineID.copy": [.ro: "Copiază", .en: "Copy", .es: "Copiar"],
        "license.machineID.copied": [.ro: "Copiat!", .en: "Copied!", .es: "¡Copiado!"],

        "menu.helpGuide": [.ro: "Ghid complet (PDF)", .en: "Full Guide (PDF)", .es: "Guía completa (PDF)"],

        // MARK: - Updates

        "menu.checkForUpdates": [.ro: "Caută actualizări…", .en: "Check for Updates…", .es: "Buscar actualizaciones…"],
        "update.upToDate": [.ro: "Ai deja ultima versiune (%@).", .en: "You're already on the latest version (%@).", .es: "Ya tienes la última versión (%@)."],
        "update.available": [.ro: "E disponibilă versiunea %@ (ai %@).", .en: "Version %@ is available (you have %@).", .es: "La versión %@ está disponible (tienes %@)."],
        "update.download": [.ro: "Actualizează acum", .en: "Update now", .es: "Actualizar ahora"],
        "update.error": [.ro: "Nu am putut verifica actualizările — verifică conexiunea la internet.", .en: "Couldn't check for updates — check your internet connection.", .es: "No se pudieron buscar actualizaciones — comprueba tu conexión a internet."],

        // MARK: - Click Effects, Keystroke Overlay, Focus Presets, Zoom+ (v1.1.0)

        "sidebar.clicks": [.ro: "Efecte Clic", .en: "Click Effects", .es: "Efectos de Clic"],
        "sidebar.keystrokes": [.ro: "Taste Afișate", .en: "Keystroke Overlay", .es: "Teclas en Pantalla"],

        "menu.clickEffects": [.ro: "Efecte de clic", .en: "Click Effects", .es: "Efectos de clic"],
        "menu.keystrokeOverlay": [.ro: "Afișare taste rapide", .en: "Keystroke Overlay", .es: "Mostrar teclas rápidas"],
        "menu.focusPreset": [.ro: "Preset rapid", .en: "Focus Preset", .es: "Preajuste rápido"],

        "prefs.multiDisplayPing": [.ro: "Semnal la schimbarea ecranului", .en: "Screen-change ping", .es: "Aviso al cambiar de pantalla"],

        "prefs.focusPreset": [.ro: "Preset rapid", .en: "Quick Preset", .es: "Preajuste rápido"],
        "prefs.focusPreset.hint": [.ro: "Aplică dintr-o mișcare o combinație de halo, spotlight și efecte de clic. Poți regla oricare valoare individual după aceea — presetul nu rămâne \"activ\", doar setează valorile o dată.",
                                    .en: "Applies a whole combination of halo, spotlight and click-effect settings in one click. You can still tweak any individual value afterwards — the preset doesn't stay \"active\", it just sets values once.",
                                    .es: "Aplica de una vez una combinación de halo, foco y efectos de clic. Puedes ajustar cualquier valor después — el preajuste no queda \"activo\", solo fija los valores una vez."],
        "preset.tutorial": [.ro: "Tutorial", .en: "Tutorial", .es: "Tutorial"],
        "preset.darkStudio": [.ro: "Studio Întunecat", .en: "Dark Studio", .es: "Estudio Oscuro"],
        "preset.presenter": [.ro: "Prezentator Contrast", .en: "Presenter High-Contrast", .es: "Presentador Alto Contraste"],
        "preset.minimalist": [.ro: "Minimalist", .en: "Minimalist", .es: "Minimalista"],

        "prefs.clickEffects.left": [.ro: "Culoare clic stânga", .en: "Left-click color", .es: "Color clic izquierdo"],
        "prefs.clickEffects.right": [.ro: "Culoare clic dreapta", .en: "Right-click color", .es: "Color clic derecho"],
        "prefs.clickEffects.double": [.ro: "Culoare dublu-clic", .en: "Double-click color", .es: "Color doble clic"],
        "prefs.clickEffects.duration": [.ro: "Durată efect", .en: "Effect duration", .es: "Duración del efecto"],
        "prefs.clickEffects.hint": [.ro: "Un inel colorat, distinct pentru clic stânga, clic dreapta și dublu-clic, apare exact unde ai dat clic — util în tutoriale, ca spectatorii să vadă instant ce tip de acțiune ai făcut.",
                                     .en: "A colored ring, distinct for left click, right click and double click, appears right where you clicked — useful in tutorials, so viewers instantly see what kind of action just happened.",
                                     .es: "Un anillo de color, distinto para clic izquierdo, clic derecho y doble clic, aparece justo donde hiciste clic — útil en tutoriales, para que se vea al instante qué acción ocurrió."],

        "prefs.keystroke.size": [.ro: "Mărime", .en: "Size", .es: "Tamaño"],
        "prefs.keystroke.opacity": [.ro: "Opacitate", .en: "Opacity", .es: "Opacidad"],
        "prefs.keystroke.duration": [.ro: "Durată afișare", .en: "Display duration", .es: "Duración en pantalla"],
        "prefs.keystroke.hint": [.ro: "Afișează lângă cursor ultima combinație apăsată — dar DOAR dacă include ⌘, ⌃ sau ⌥. O literă simplă tastată (de ex. într-un câmp de parolă) nu apare niciodată — nu e un keylogger, doar un afișaj de scurtături pentru tutoriale.",
                                  .en: "Shows the last combo pressed near the cursor — but ONLY when it includes ⌘, ⌃ or ⌥. A plain letter typed anywhere (e.g. into a password field) never appears — this is a shortcut viewer for tutorials, not a keylogger.",
                                  .es: "Muestra junto al cursor la última combinación pulsada — pero SOLO si incluye ⌘, ⌃ u ⌥. Una letra simple escrita (por ejemplo en un campo de contraseña) nunca aparece — es un visor de atajos para tutoriales, no un keylogger."],

        "prefs.zoom.colorPicker": [.ro: "Inspector de culoare", .en: "Color inspector", .es: "Inspector de color"],
        "prefs.zoom.lockFrame": [.ro: "Tastă blocare cadru", .en: "Lock frame key", .es: "Tecla de bloqueo del marco"],
        "prefs.zoom.lockFrame.hint": [.ro: "Cât ții tasta de Zoom apăsată, apasă și tasta de blocare (implicit ⌥L) ca lupa să rămână fixă pe loc — utilă ca să eliberezi mâna de pe poziția cursorului și totuși să arăți/discuți zona mărită. Se deblochează automat când eliberezi tasta de Zoom.",
                                       .en: "While holding the Zoom key, also press the lock key (default ⌥L) to freeze the loupe in place — lets you stop tracking the cursor position and still point at/discuss the magnified area. Unlocks automatically when you release the Zoom key.",
                                       .es: "Mientras mantienes la tecla de Zoom, pulsa también la tecla de bloqueo (⌥L por defecto) para congelar la lupa en su sitio — así puedes soltar el seguimiento del cursor y aun así señalar la zona ampliada. Se desbloquea automáticamente al soltar la tecla de Zoom."],

        "prefs.zoom.scaling": [.ro: "Scalare imagine", .en: "Image scaling", .es: "Escalado de imagen"],
        "prefs.zoom.scaling.smooth": [.ro: "Fluidă", .en: "Smooth", .es: "Fluido"],
        "prefs.zoom.scaling.crisp": [.ro: "Pixeli reali", .en: "Crisp Pixels", .es: "Píxeles reales"],

        "help.clicks.title": [.ro: "Efecte de Clic", .en: "Click Effects", .es: "Efectos de Clic"],
        "help.clicks.body": [.ro: "Activează-le din Preferințe → Efecte Clic (sau din meniu). Un inel colorat apare la fiecare clic stânga, clic dreapta sau dublu-clic — fiecare cu propria culoare, reglabilă — și dispare treptat. Ideal pentru tutoriale, ca privitorii să vadă exact ce ai apăsat.",
                              .en: "Turn them on from Preferences → Click Effects (or the menu). A colored ring appears on every left click, right click or double click — each with its own adjustable color — and fades out on its own. Great for tutorials, so viewers see exactly what you clicked.",
                              .es: "Actívalos desde Preferencias → Efectos de Clic (o el menú). Un anillo de color aparece en cada clic izquierdo, derecho o doble clic — cada uno con su propio color ajustable — y se desvanece solo. Ideal para tutoriales, así los espectadores ven exactamente qué pulsaste."],

        "help.keystrokes.title": [.ro: "Afișare Taste Rapide", .en: "Keystroke Overlay", .es: "Teclas en Pantalla"],
        "help.keystrokes.body": [.ro: "Activeaz-o din Preferințe → Taste Afișate (sau din meniu). Când apeși o combinație cu ⌘, ⌃ sau ⌥ (de ex. ⌘C), apare lângă cursor și dispare după o secundă — perfect ca spectatorii unui tutorial să vadă ce scurtătură tocmai ai folosit. Literele simple tastate, fără niciun modificator, NU apar niciodată.",
                                  .en: "Turn it on from Preferences → Keystroke Overlay (or the menu). When you press a combo with ⌘, ⌃ or ⌥ (e.g. ⌘C), it appears near the cursor and fades after about a second — perfect for tutorial viewers to see which shortcut you just used. Plain letters typed with no modifier NEVER show up.",
                                  .es: "Actívala desde Preferencias → Teclas en Pantalla (o el menú). Al pulsar una combinación con ⌘, ⌃ u ⌥ (p. ej. ⌘C), aparece junto al cursor y se desvanece al cabo de un segundo — perfecto para que los espectadores de un tutorial vean qué atajo usaste. Las letras simples sin modificador NUNCA aparecen."],
    ]
}
