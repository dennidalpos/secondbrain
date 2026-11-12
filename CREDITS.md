# Credits e Attribuzioni Terze Parti

Questo documento riconosce e ringrazia progetti, standard, toolchain e riferimenti metodologici open source che supportano l'architettura e l'operatività di **SecondBrain**.

---

## 1. Toolchain e Runtime

### PowerShell 7 (PowerShell Core)
- **Autore / Manutentore**: Microsoft Corporation e PowerShell Team
- **Licenza**: [MIT License](https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt)
- **Descrizione**: Motore di automazione e linguaggio di scripting moderno, multipiattaforma e deterministico su Windows, Linux e macOS.

### Git Version Control System
- **Autore**: Linus Torvalds, Junio C Hamano e contributori Git
- **Licenza**: GNU General Public License v2 (GPL-2.0)
- **Descrizione**: Sistema di controllo di versione distribuito standard per il monitoraggio e la cooperazione deterministica tra repository e postazioni.

### MarkItDown

Il convertitore opzionale delle fonti usa MarkItDown 0.1.9, sviluppato da Microsoft e distribuito con licenza MIT. Gli extra `pdf` e `docx` abilitano la conversione di questi formati in Markdown. [Release 0.1.9](https://pypi.org/project/markitdown/0.1.9/) · [Licenza upstream](https://github.com/microsoft/markitdown/blob/main/LICENSE)

Il [manifest](scripts/source-requirements.txt) dichiara `markitdown[pdf,docx]==0.1.9`. Il [lock](scripts/source-requirements.lock.txt) fissa le versioni di 30 pacchetti, incluso il convertitore, con gli hash sha256 richiesti da `pip --require-hashes`. L'ambiente Python 3.13 dedicato risiede nella sottocartella `sources/python` del runtime della postazione. I pacchetti si installano localmente e restano fuori dalle build dei prodotti e dalla distribuzione di SecondBrain. [Configurazione del convertitore](docs/riferimento/authoritative-sources.md)

### Orchestratore desktop (`app/orchestrator`)

Il repository contiene il sorgente dell'app e i lock delle dipendenze; nessun binario o pacchetto di installazione è distribuito: l'app si compila sulla postazione con `npm ci` e `cargo`. Versioni risolte dai lock, licenze dai metadati dei pacchetti (`package.json` installati, `cargo metadata`) del 2026-11-12.

| Componente | Versione | Licenza (SPDX) | Ruolo | Sorgente |
| --- | --- | --- | --- | --- |
| Tauri (`tauri`, `tauri-build`) | 2.12.5, 2.7.4 | Apache-2.0 OR MIT | Runtime dell'app e build | [tauri-apps/tauri](https://github.com/tauri-apps/tauri) |
| `tauri-plugin-dialog` | 2.8.4 | Apache-2.0 OR MIT | Selettori di file e cartelle | [tauri-apps/plugins-workspace](https://github.com/tauri-apps/plugins-workspace) |
| `serde`, `serde_json` | 1.0.229, 1.0.154 | MIT OR Apache-2.0 | Serializzazione | [serde-rs](https://github.com/serde-rs) |
| `@tauri-apps/api`, `@tauri-apps/plugin-dialog` | 2.5.0, 2.2.2 | Apache-2.0 OR MIT | Interfaccia TypeScript | [tauri-apps](https://github.com/tauri-apps) |
| Vite | 6.4.6 | MIT | Solo sviluppo: build del frontend | [vitejs/vite](https://github.com/vitejs/vite) |
| TypeScript | 5.8.3 | Apache-2.0 | Solo sviluppo: compilatore | [microsoft/TypeScript](https://github.com/microsoft/TypeScript) |
| Playwright (`@playwright/test`) | 1.65.0 | Apache-2.0 | Solo sviluppo: test end-to-end | [microsoft/playwright](https://github.com/microsoft/playwright) |
| Tauri CLI (`@tauri-apps/cli`) | 2.5.0 | Apache-2.0 OR MIT | Solo sviluppo: build dell'app | [tauri-apps/tauri](https://github.com/tauri-apps/tauri) |

Dipendenze transitive: 423 crate Rust nel lock (tutte le piattaforme) con licenze permissive, salvo 7 crate MPL-2.0 (`cssparser`, `cssparser-macros`, `selectors`, `dtoa-short`, `option-ext`; copyleft debole a livello di file) e 18 crate Unicode-3.0 (famiglia ICU4X, licenza permissiva con avviso); `r-efi` offre anche LGPL-2.1-or-later in alternativa a MIT e Apache-2.0. Gli 82 pacchetti npm del lock sono permissivi (MIT, ISC, Apache-2.0, BSD-3-Clause); i 60 binari opzionali per altre piattaforme di esbuild, Rollup e Tauri CLI non sono installati qui e la loro licenza non è stata letta. Se un binario dell'app viene distribuito, vanno allegati gli avvisi di licenza delle dipendenze incluse, l'indicazione del sorgente dei file MPL-2.0 e l'avviso Unicode-3.0.

Le icone in `app/orchestrator/src-tauri/icons/` non corrispondono al logo predefinito di Tauri; la loro provenienza non è registrata nel repository.

---

## 2. Standard e Specifiche Tecniche

### JSON Schema (Draft 2020-12)
- **Organizzazione**: Internet Engineering Task Force (IETF) / JSON Schema Community
- **Sito web**: [json-schema.org](https://json-schema.org/)
- **Descrizione**: Specifica per la validazione dichiarativa della struttura e dei contratti dati dei file di configurazione, cataloghi prompt e tracker.

### SPDX (Software Package Data Exchange)
- **Organizzazione**: Linux Foundation
- **Licenza**: Creative Commons Attribution License 3.0 (CC-BY-3.0)
- **Sito web**: [spdx.dev](https://spdx.dev/)
- **Descrizione**: Standard internazionale (ISO/IEC 5962:2021) per la comunicazione accurata delle informazioni su licenze e proprietà intellettuale del software.

### OWASP Top 10
- **Organizzazione**: OWASP Foundation
- **Licenza**: Creative Commons Attribution Share-Alike 4.0 (CC-BY-SA 4.0)
- **Sito web**: [owasp.org](https://owasp.org/)
- **Descrizione**: Documento di consenso e standard di consapevolezza sulle principali vulnerabilità di sicurezza e buone pratiche di hardening del codice.

---

## 3. Riferimenti Metodologici

### Metodologia PARA (Projects, Areas, Resources, Archives)
- **Autore**: Tiago Forte / Forte Labs
- **Riferimento**: *Building a Second Brain* (2022)
- **Descrizione**: Tassonomia concettuale adottata da SecondBrain per organizzare la conoscenza, le responsabilità continuative e le memorie di progetto senza dispersioni.

### Guide e Specifiche di Prompt Engineering per Coding Agent
- **Anthropic**: [Claude Prompt Library & Common Workflows](https://code.claude.com/docs/en/prompt-library)
- **OpenAI**: [OpenAI Prompt Engineering Guides](https://developers.openai.com/api/docs/guides/prompt-engineering)
- **Google DeepMind / Antigravity**: Linee guida di ingegneria dei prompt deterministici e architettura agentica per pair programming.
- **Anthropic**: [Prompt engineering overview](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/overview) (ruolo, tag XML, formato di output esplicito) e [Claude Code memory](https://code.claude.com/docs/en/memory) (`CLAUDE.md` e import `@AGENTS.md`).
- **Google**: [Prompt design strategies](https://ai.google.dev/gemini-api/docs/prompting-strategies).
- **AGENTS.md**: [agents.md](https://agents.md), formato aperto delle istruzioni per agenti di codifica.
- **CO-STAR**: framework di struttura dei prompt (Context, Objective, Style, Tone, Audience, Response) del concorso GovTech Singapore.

---

## 4. Testi di terzi nel registro delle fonti

`03-resources/authoritative-sources/entries/*/versions/` contiene, dal #478, trascrizioni in Markdown di fonti con `rights.status` `public-reusable`: conversioni di formato degli originali, che restano locali (`versions/*/originals/` è escluso da Git). I file sono identificati per hash e non si modificano; gli avvisi richiesti dalle licenze sono raccolti qui. Condizioni lette dalle pagine degli enti il 2026-11-12.

| Fonte (scheda) | Titolare | Condizioni | Obblighi per le copie nel repository |
| --- | --- | --- | --- |
| OWASP ASVS 5.0.0 (`owasp-asvs`) | OWASP ASVS contributors | [CC-BY-SA-4.0](https://github.com/OWASP/ASVS/blob/master/LICENSE.md) | Attribuzione, link alla licenza, indicazione delle modifiche (conversione in Markdown); le trascrizioni derivate restano CC-BY-SA-4.0 |
| OWASP Cheat Sheet Series: Password Storage, File Upload (`owasp-password-storage`, `owasp-file-upload`) | OWASP Cheat Sheet Series contributors | [CC-BY-SA-4.0](https://github.com/OWASP/CheatSheetSeries/blob/master/LICENSE.md) | Come sopra |
| WCAG 2.2 (`w3c-wcag`) | World Wide Web Consortium | [W3C Document License 2023](https://www.w3.org/copyright/document-license-2023/) | Link all'originale, avviso di copyright e sezione STATUS conservati; nessuna presentazione della trascrizione come specifica tecnica |
| NIST SP 800-63B-4, SP 800-218 (`nist-digital-identity`, `nist-ssdf`) | National Institute of Standards and Technology | [NIST Open License](https://www.nist.gov/open/license): opere di dipendenti federali non soggette a copyright negli USA (17 U.S.C. §105) | Citazione di NIST e degli autori; fuori dagli USA possono valere diritti riservati |
| EFF Large Wordlist (`eff-diceware`) | Electronic Frontier Foundation | [Politica del sito EFF](https://www.eff.org/copyright): materiale originale CC-BY-4.0 | Attribuzione a EFF; la pagina della lista non nomina una licenza propria (da verificare) |
| AI Act, GDPR e consolidati, Regolamento (UE) 2026/1744 (`eu-ai-act`, `eu-gdpr`, `eu-gdpr-consolidation`, `eu-ai-omnibus-2026`) | Unione europea | [Avviso legale EUR-Lex](https://eur-lex.europa.eu/content/legal-notice/legal-notice.html), decisione 2011/833/UE | Citazione della fonte; fa fede la Gazzetta ufficiale. Pagina EUR-Lex non leggibile il 2026-11-12 (risposta vuota): condizioni da riverificare |
| Quadro AI della Commissione (`ec-ai-framework`) | Commissione europea | [Avviso legale](https://commission.europa.eu/legal-notice_en): CC-BY-4.0 salvo indicazione contraria | Attribuzione «© European Union», indicazione delle modifiche; esclusi contenuti di terzi e loghi |
| Quadro giuridico EDPB (`edpb-legal-framework`) | European Data Protection Board | [Copyright EDPB](https://www.edpb.europa.eu/copyright_en): riuso anche commerciale | Citazione della fonte, nessuna distorsione del significato, indicazioni di autore e fonte invariate |
| L. 132/2025, D.Lgs. 151/2015, D.Lgs. 185/2016 (`it-ai-law-132-2025`, `it-dlgs-151-2015`, `it-dlgs-185-2016`) | Repubblica italiana (Gazzetta Ufficiale) | [Art. 5 L. 633/1941](https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:1941-04-22;633~art5): la legge sul diritto d'autore non si applica agli atti ufficiali | Citazione della fonte; i fascicoli GU contengono anche altri atti, conservati come contesto |

Avviso richiesto dalla W3C Document License: Copyright © 2020-2024 World Wide Web Consortium. W3C®. This software or document includes material copied from or derived from Web Content Accessibility Guidelines (WCAG) 2.2, https://www.w3.org/TR/WCAG22/.

## 5. Note Legali

Tutti i marchi, loghi e nomi commerciali registrati citati in questo repository appartengono ai rispettivi proprietari. Il software **SecondBrain** è distribuito sotto licenza [MIT](LICENSE).

### Compatibilità con la licenza MIT del progetto

| Componente | Licenza | Uso in SecondBrain | Esito |
| --- | --- | --- | --- |
| PowerShell 7 | MIT | Runtime richiesto, non ridistribuito | Compatibile |
| Git | GPL-2.0 | Strumento esterno invocato da riga di comando, non incorporato né ridistribuito | Compatibile (nessun lavoro derivato) |
| MarkItDown 0.1.9 | MIT | Dipendenza diretta opzionale per la conversione delle fonti, installata nel runtime | Licenza del pacchetto diretto |
| Tauri, serde e dipendenze dell'orchestratore | Apache-2.0 OR MIT; transitive con MPL-2.0 e Unicode-3.0 | Sorgente e lock nel repository, compilati in locale; nessun binario distribuito | Licenze permissive; obblighi di avviso solo se si distribuisce un binario |
| Trascrizioni del registro delle fonti | CC-BY-SA-4.0, W3C Document License, CC-BY-4.0, condizioni EDPB e NIST, atti ufficiali | Testi inclusi nel repository (§4) | Licenze proprie, non coperte dalla licenza MIT; avvisi in §4 |
| JSON Schema, SPDX, PARA | Specifiche e riferimenti | Citati nella documentazione, nessun codice incorporato | Compatibile |

La licenza MIT copre il codice e i testi originali di SecondBrain; i testi di terzi del §4 restano sotto le rispettive condizioni. Per i pacchetti del lock Python valgono le licenze e gli avvisi dei rispettivi progetti. L'inventario delle versioni è nel lock. Strumenti opzionali usati localmente per le catture restano fuori dalla distribuzione.
