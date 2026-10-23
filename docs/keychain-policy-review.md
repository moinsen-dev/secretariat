# Quellprüfung Keychain-Dialogpolitik

Stand: 2026-10-23T08:44:39+02:00. Delegierter Kritiker; ausschließlich lokale Header und öffentliche Primärquellen gelesen. **Kein Aufruf von Security-/Keychain-Funktionen, keine Credentials, keine System-/Policyänderung und kein weiterer Dialogtest.**

## Ergebnis und Scope

**Die scoped Legacy-Unterdrückung ist fachlich empfohlen.** Aus dem veröffentlichten Apple-Code folgt ein prozessweiter Zustand in Security.framework, keine Änderung der Policies fremder Apps oder einer persistenten Systemeinstellung:

- `SecKeychainSetUserInteractionAllowed` delegiert an `globals().setUserInteractionAllowed`; der Getter an denselben lokalen Globalszustand. [Apple SecKeychain.cpp](https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_keychain/lib/SecKeychain.cpp)
- Der Setter schreibt ein bool-Feld `mUI`; Globals wird über ModuleNexus gehalten. Daraus wird die Wahl der Anmelde-/Zugriffs-Credentials für die einzelnen Anfragen abgeleitet. Das ist ein innerhalb des aufrufenden Prozesses geteilter Bibliothekszustand. [Apple Globals.h](https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_keychain/lib/Globals.h), [Apple Globals.cpp](https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_keychain/lib/Globals.cpp)

Diese Scope-Aussage ist eine Ableitung aus der geprüften veröffentlichten Implementierung; keine eigene Laufzeitmessung am installierten Security.framework. Weil alle Threads des Prozesses denselben Zustand verwenden, muss ein enger Scope exakt den vorherigen Zustand wiederherstellen. „Global“ darf hier nicht als systemweite Änderung fremder App-Policies umgesetzt werden.

## Empfehlung für check und Fixturehelper

1. Alten Zustand über Get lesen und dessen Erfolg prüfen; Set(false) ebenfalls prüfen. Bei Fehler keine Credentialabfrage beginnen.
2. Nur die betreffenden Legacy-Aufrufe unter diesen Scope nehmen; Wiederherstellung mit defer/RAII auf den tatsächlich gelesenen alten Zustand, nicht pauschal true. Prozessinterne konkurrierende Scoped-Aufrufe serialisieren bzw. korrekt verschachteln.
3. Normale GUI/run-Policy nicht verändern. Ein eigener check-CLI-Prozess wirkt nicht auf den separaten GUI-Prozess. Watchdog-Prozessende lässt dessen lokalen Speicherzustand verfallen; der Watchdog ist trotzdem kein Beweis, dass ein bereits gestarteter Systemdialog sicher verschwindet.
4. Keine Preferences, Default-/Suchlisten oder fremden Keychains ändern; keine Entsperrung oder interaktiver Fallback.

Chromiums aktuelle Implementierung behandelt die SecItem-UI-Flags für file-based Keychains ausdrücklich als unzureichend (FB16959400) und verwendet Get/Set mit scoped Wiederherstellung. Das bestätigt, dass die frühere Ableitung allein aus der SecItem-Headersemantik für diese Keychainart zu weit ging. [Chromium ScopedKeychainUserInteractionAllowed](https://chromium.googlesource.com/chromium/src/crypto/+/refs/heads/main/apple/scoped_keychain_user_interaction_allowed.cc)

## Trusted-App-Pfad

Der lokale aktuelle SDK-Header `Security.framework/Headers/SecTrustedApplication.h` verlangt für App-Bundles das Bundleverzeichnis; für eigenständige Werkzeuge ihren Toolpfad. Der Fixturehelper muss beim Vertrauen der Secretariat-App daher das tatsächliche `.app`-Verzeichnis verwenden, nicht `Contents/MacOS/Secretariat`. Ein eigener Helper darf nur dann explizit vertraut werden, wenn der künstliche Fixtureablauf dies benötigt; keine beliebigen Programme freigeben und Cleanup weiterhin über Label/Service/Account begrenzen.

## Auswirkung auf bisherige Nachweise

Die frühere reine Quellfreigabe von UI-Fail/LAContext war kein erfolgreicher Realnachweis für file-based-Keychains. Der erneut beobachtete Dialog ist ein tatsächlicher Fehler des bisherigen Nichtinteraktivitätsversprechens. Ein bestandener Watchdog-Memorytest belegt nur begrenzten CLI-Exit. Vor Abschluss des betroffenen Produktpfads muss die Korrektur am tatsächlichen aktuellen Quellstand bewertet und ein geeigneter, vom Root verantworteter normaler Ablauf getrennt belegt werden. Dieser Bericht führt selbst keine solchen Credentialaktionen aus.

## Aktueller Guard-Quellstand

**PASS für KeychainStore und den CLI-Defaultpfad.** `withInteractionPolicy` sperrt mit einem statischen NSRecursiveLock jede read/set/delete-Operation einschließlich interaktiver Storeaufrufe. Für false wird Get geprüft, Set(false) geprüft und der exakt gelesene vorherige Wert per defer wiederhergestellt. Bei Vorbereitungsfehler läuft die Operation nicht. Der CLI-Default-Vault verwendet jetzt auch für run ausdrücklich false; AgentService bleibt false. Die normale GUI erstellt weiterhin interaktive Vaults. Damit ist die empfohlene prozessinterne Trennung nachvollziehbar implementiert. Der Restorestatus wird verworfen; im veröffentlichten Apple-Code ist dies lediglich eine lokale Bool-Zuweisung, keine entfernte oder persistente Policyoperation.

Der Helper bestimmt das .app-Verzeichnis aus dem Executable und übergibt diesen Bundlepfad. Das Akzeptanzskript ermittelt die Developer-ID-Identität des tatsächlichen Appartefakts und signiert den Helper damit; kein fremdes Paket wird umsigniert. Die Berichte über echte negative/positive Dummytests stammen von Root; dieser Prüfer hat sie nicht selbst ausgeführt und keine Security-Funktion aufgerufen.

**Testpipeline-Befund behoben und erneut lesend geprüft:** Der Legacy-Scope steht jetzt bereits vor inventory, so dass auch dessen SecItemCopyMatching geschützt ist. Der direkte security-Diagnoseprozess wurde entfernt; Cleanup ruft wieder den korrekt signierten scopedHelper mit festem Fixturelabel/Service/Account auf. Die zuvor ungeschützten getrennten Prozesse sind damit nicht mehr im Akzeptanzskript enthalten. PASS für den aktuellen geprüften Quellpfad, ohne unabhängigen tatsächlichen Credentialtest.
