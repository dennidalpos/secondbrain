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

Il [manifest](scripts/source-requirements.txt) dichiara `markitdown[pdf,docx]==0.1.9`. Il [lock](scripts/source-requirements.lock.txt) fissa le versioni di 30 pacchetti, incluso il convertitore. L'ambiente Python 3.13 dedicato risiede nella sottocartella `sources/python` del runtime della postazione. I pacchetti si installano localmente e restano fuori dalle build dei prodotti e dalla distribuzione di SecondBrain. [Configurazione del convertitore](docs/riferimento/authoritative-sources.md)

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

## 4. Note Legali

Tutti i marchi, loghi e nomi commerciali registrati citati in questo repository appartengono ai rispettivi proprietari. Il software **SecondBrain** è distribuito sotto licenza [MIT](LICENSE).

### Compatibilità con la licenza MIT del progetto

| Componente | Licenza | Uso in SecondBrain | Esito |
| --- | --- | --- | --- |
| PowerShell 7 | MIT | Runtime richiesto, non ridistribuito | Compatibile |
| Git | GPL-2.0 | Strumento esterno invocato da riga di comando, non incorporato né ridistribuito | Compatibile (nessun lavoro derivato) |
| MarkItDown 0.1.9 | MIT | Dipendenza diretta opzionale per la conversione delle fonti, installata nel runtime | Licenza del pacchetto diretto |
| JSON Schema, SPDX, OWASP, PARA | Specifiche e riferimenti | Citati nella documentazione, nessun codice incorporato | Compatibile |

Per i pacchetti del lock Python valgono le licenze e gli avvisi dei rispettivi progetti. L'inventario delle versioni è nel lock. Strumenti opzionali usati localmente per le catture restano fuori dalla distribuzione.
